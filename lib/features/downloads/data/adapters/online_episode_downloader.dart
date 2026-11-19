import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

import 'package:iris/features/downloads/data/adapters/hls_playlist.dart';
import 'package:iris/features/downloads/domain/entities/download_failure.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';
import 'package:iris/features/online_sources/domain/online_episode_files.dart';
import 'package:iris/features/online_sources/domain/online_stream_choice.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/online/online_source_link.dart';
import 'package:iris/shared/torrent/preparation_cancelled_exception.dart';

/// Why an online download stopped; [message] is stored with the download
/// and read back by [downloadFailureFrom].
class OnlineDownloadException implements Exception {
  const OnlineDownloadException(this.message);

  final String message;

  @override
  String toString() => 'OnlineDownloadException: $message';
}

/// How far an online download is. [totalBytes] is an estimate while an HLS
/// episode loads, 0 until there is one to give.
class OnlineDownloadProgress {
  const OnlineDownloadProgress({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.rateBytesPerSecond,
    this.videoHeight,
  });

  final int downloadedBytes;
  final int totalBytes;
  final int rateBytesPerSecond;
  final int? videoHeight;
}

/// One episode loading; [cancel] stops it.
abstract interface class OnlineDownloadTask {
  Stream<OnlineDownloadProgress> get progress;

  /// The finished video, or null when the task was cancelled. Fails with an
  /// [OnlineDownloadException] or a [FileSystemException].
  Future<File?> get done;

  /// Stops the task; completes once nothing writes to its folder any more.
  Future<void> cancel();
}

/// Loads online episodes to disk: an HLS stream segment by segment, glued
/// into one file mpv plays as it is (MPEG-TS, or fragmented MP4 after its
/// init segment), and an mp4 in one piece with `Range`. DASH is not
/// loaded; another quality of the episode in HLS or mp4 is taken instead.
///
/// A run that stopped (pause, a lost connection, the app closed) picks up
/// from what is on disk. Links expire: a server that refuses a segment is
/// asked for a fresh link, and the download goes on when the episode's
/// segment list is unchanged, or starts over when it changed.
class OnlineEpisodeDownloader {
  OnlineEpisodeDownloader({
    required OnlineSourcesRepository repository,
    required Dio dio,
    Future<void> Function(Duration delay)? delay,
    DateTime Function() now = DateTime.now,
  }) : _repository = repository,
       _dio = dio,
       _delay = delay ?? Future<void>.delayed,
       _now = now;

  final OnlineSourcesRepository _repository;
  final Dio _dio;
  final Future<void> Function(Duration delay) _delay;
  final DateTime Function() _now;

  /// The release's episodes, as files to choose from (their sizes are not
  /// known before they load), and the heights its first episode can be
  /// loaded in, tallest first; none when that episode gave no answer.
  Future<({List<DownloadableFile> files, List<int> qualities})> episodes(
    OnlineSourceLink link,
  ) async {
    final release = await _release(link);
    final indices = onlineEpisodeFileIndices(release);
    return (
      files: [
        for (final (position, episode) in release.episodes.indexed)
          DownloadableFile(
            index: indices[position],
            name: onlineEpisodeFileName(episode.number, episode.title),
            relativePath: '',
            size: 0,
          ),
      ],
      qualities: await _qualities(release),
    );
  }

  /// A release's episodes come in the same heights, as far as the sites go:
  /// the first one speaks for all.
  Future<List<int>> _qualities(OnlineRelease release) async {
    if (release.episodes.isEmpty) return const [];
    try {
      final streams = await _repository.resolveStreams(
        provider: release.provider,
        episodeId: release.episodes.first.id,
      );
      return onlineQualities(streams, downloadable: true);
    } on Object catch (error) {
      developer.log(
        'No qualities for ${release.provider.name}/${release.id}: $error',
        name: 'iris.downloads.online',
      );
      return const [];
    }
  }

  /// Starts loading episode [fileIndex] of [link] into [directory], at most
  /// [maxQuality] high (null: the best).
  OnlineDownloadTask start({
    required OnlineSourceLink link,
    required int fileIndex,
    required Directory directory,
    int? maxQuality,
  }) {
    final task = _Task(
      downloader: this,
      link: link,
      fileIndex: fileIndex,
      directory: directory,
      maxQuality: maxQuality,
    );
    unawaited(task.run());
    return task;
  }

  Future<OnlineRelease> _release(OnlineSourceLink link) {
    final provider = OnlineProvider.named(link.provider);
    if (provider == null) {
      throw ArgumentError.value(link.provider, 'link', 'Unknown provider');
    }
    return _repository.fetchRelease(provider: provider, id: link.releaseId);
  }
}

/// What a run leaves next to the video, for the next run to go on from.
const _stateFileName = 'online_download.json';

/// Tries for one request before the link is renewed.
const _attempts = 4;

/// Fresh links asked for in a row with nothing loaded in between.
const _renewals = 3;

/// Waits between tries to reach the site while the network is gone, about
/// two and a half minutes in all: a short drop leaves the queue alone.
const _offlineWaits = [2, 4, 8, 16, 30, 30, 30, 30];

class _Task implements OnlineDownloadTask {
  _Task({
    required this.downloader,
    required this.link,
    required this.fileIndex,
    required this.directory,
    required this.maxQuality,
  });

  final OnlineEpisodeDownloader downloader;
  final OnlineSourceLink link;
  final int fileIndex;
  final Directory directory;
  final int? maxQuality;

  final _progress = StreamController<OnlineDownloadProgress>.broadcast();
  final _done = Completer<File?>();
  final _stopped = Completer<void>();
  final _cancelToken = CancelToken();
  bool _cancelled = false;

  /// Stops waiting for provider replies and retries as soon as pause is asked.
  final _cancelRequested = Completer<void>();
  late final _meter = _RateMeter(downloader._now);

  @override
  Stream<OnlineDownloadProgress> get progress => _progress.stream;

  @override
  Future<File?> get done => _done.future;

  @override
  Future<void> cancel() async {
    _cancelled = true;
    if (!_cancelRequested.isCompleted) _cancelRequested.complete();
    _cancelToken.cancel();
    await _stopped.future;
  }

  Future<void> run() async {
    try {
      final file = await _load();
      if (!_done.isCompleted) _done.complete(_cancelled ? null : file);
    } on _Cancelled {
      if (!_done.isCompleted) _done.complete(null);
    } on Object catch (error, stackTrace) {
      if (_done.isCompleted) return;
      if (_cancelled) {
        _done.complete(null);
        return;
      }
      developer.log(
        'Online episode $fileIndex of $link did not load.',
        name: 'iris.downloads.online',
        error: error,
        stackTrace: stackTrace,
      );
      _done.completeError(
        error is OnlineDownloadException || error is FileSystemException
            ? error
            : const OnlineDownloadException(downloadConnectionLostMessage),
      );
    } finally {
      _stopped.complete();
      await _progress.close();
    }
  }

  Future<File> _load() async {
    await directory.create(recursive: true);
    final episodeId = await _episodeId();
    var renewalsLeft = _renewals;
    while (true) {
      _checkCancelled();
      final state = await _readState();
      final stream = await _pickStream(episodeId, state);
      try {
        if (stream.subtitleUrl != null) {
          final (text: subtitle, uri: _) = await _fetchText(
            Uri.parse(stream.subtitleUrl!),
          );
          if (!subtitle.trimLeft().startsWith('WEBVTT')) {
            throw const OnlineDownloadException(downloadCouldNotStartMessage);
          }
          await File(
            path.join(directory.path, 'episode.vtt'),
          ).writeAsString(subtitle);
        }
        return stream.format == OnlineStreamFormat.mp4
            ? await _loadMp4(stream, state, () => renewalsLeft = _renewals)
            : await _loadHls(stream, state, () => renewalsLeft = _renewals);
      } on _LinkRefused catch (refusal) {
        if (--renewalsLeft < 0) {
          throw const OnlineDownloadException(downloadConnectionLostMessage);
        }
        developer.log(
          'The video server refused (${refusal.reason}); renewing the link.',
          name: 'iris.downloads.online',
        );
      }
    }
  }

  Future<String> _episodeId() async {
    final release = await _whileOffline(() => downloader._release(link));
    final position = onlineEpisodeFileIndices(release).indexOf(fileIndex);
    if (position < 0) {
      throw const OnlineDownloadException(downloadCouldNotStartMessage);
    }
    return release.episodes[position].id;
  }

  /// The stream to load: the quality an earlier run loaded, when the server
  /// still has it, otherwise the one [maxQuality] asks for.
  Future<OnlineStream> _pickStream(String episodeId, _State? state) async {
    final provider = OnlineProvider.named(link.provider)!;
    final streams = await _whileOffline(
      () => downloader._repository.resolveStreams(
        provider: provider,
        episodeId: episodeId,
      ),
    );
    final loadable = [
      for (final stream in streams)
        if (stream.format != OnlineStreamFormat.dash) stream,
    ];
    if (loadable.isEmpty) {
      throw const OnlineDownloadException(downloadNotDownloadableMessage);
    }
    if (state != null) {
      for (final stream in loadable) {
        if (stream.quality == state.quality &&
            stream.format.name == state.format) {
          return stream;
        }
      }
    }
    return chooseOnlineStream(
      loadable,
      maxQuality: maxQuality,
      downloadable: true,
    )!;
  }

  Future<File> _loadHls(
    OnlineStream stream,
    _State? state,
    void Function() onLoaded,
  ) async {
    final playlist = await _playlist(stream);
    final plan = playlist.plan;
    final videoHeight = playlist.height;
    final pieces = [?plan.init, ...plan.segments];
    // Older checkpoints may have counted empty pieces as downloaded.
    final playlistHash = 'v2:${plan.fingerprint}';
    final output = File(
      path.join(
        directory.path,
        plan.fragmentedMp4 ? 'episode.mp4' : 'episode.ts',
      ),
    );
    final resumable =
        state != null &&
        state.format == stream.format.name &&
        state.quality == stream.quality &&
        state.pieces == pieces.length &&
        state.playlistHash == playlistHash &&
        await output.exists() &&
        await output.length() >= state.bytes;
    if (state != null && !resumable) {
      developer.log(
        'The episode changed since the last run; loading it anew.',
        name: 'iris.downloads.online',
      );
    }
    var done = resumable ? state.done : 0;
    var bytes = resumable ? state.bytes : 0;
    final totalSeconds = plan.segments.fold<double>(
      0,
      (sum, segment) => sum + segment.seconds,
    );

    final sink = await output.open(mode: FileMode.append);
    try {
      await sink.truncate(bytes);
      await sink.setPosition(bytes);
      _report(
        bytes,
        _estimate(plan, done, bytes, totalSeconds),
        videoHeight: videoHeight,
      );
      while (done < pieces.length) {
        _checkCancelled();
        final data = await _fetchBytes(pieces[done].uri);
        await sink.writeFrom(data);
        done++;
        bytes += data.length;
        onLoaded();
        await _writeState(
          _State(
            format: stream.format.name,
            quality: stream.quality,
            pieces: pieces.length,
            done: done,
            bytes: bytes,
            playlistHash: playlistHash,
          ),
        );
        _report(
          bytes,
          _estimate(plan, done, bytes, totalSeconds),
          videoHeight: videoHeight,
        );
      }
    } finally {
      await sink.close();
    }
    await _deleteState();
    _report(bytes, bytes, videoHeight: videoHeight);
    return output;
  }

  /// The loaded share of [plan] scaled up to the whole: by play time when
  /// the playlist gives it, otherwise by count.
  int _estimate(HlsPlan plan, int done, int bytes, double totalSeconds) {
    final segmentsDone = done - (plan.init == null ? 0 : 1);
    if (segmentsDone <= 0 || bytes <= 0) return 0;
    if (totalSeconds > 0) {
      final secondsDone = plan.segments
          .take(segmentsDone)
          .fold<double>(0, (sum, segment) => sum + segment.seconds);
      if (secondsDone > 0) return (bytes * totalSeconds / secondsDone).round();
    }
    return (bytes * plan.segments.length / segmentsDone).round();
  }

  /// A master playlist chooses a variant using the requested quality.
  Future<({HlsPlan plan, int? height})> _playlist(OnlineStream stream) async {
    final playlist = await _fetchText(Uri.parse(stream.url));
    final variant = HlsPlaylist.pickVariant(
      playlist.text,
      playlist.uri,
      quality: maxQuality ?? stream.quality,
    );
    final media = variant == null ? playlist : await _fetchText(variant.uri);
    final plan = HlsPlaylist.parseMedia(
      media.text,
      media.uri,
      variantHeight: variant?.height,
    );
    if (plan == null) {
      throw const OnlineDownloadException(downloadNotDownloadableMessage);
    }
    return (
      plan: plan,
      height: _positiveHeight(variant?.height ?? stream.quality),
    );
  }

  Future<File> _loadMp4(
    OnlineStream stream,
    _State? state,
    void Function() onLoaded,
  ) async {
    final output = File(path.join(directory.path, 'episode.mp4'));
    if (state != null &&
        (state.format != stream.format.name ||
            state.quality != stream.quality)) {
      await _deleteState();
      state = null;
    }
    var validator = state?.mp4;
    final url = Uri.parse(stream.url);
    var bestBytes = validator != null && await output.exists()
        ? await output.length()
        : 0;
    var attempt = 0;
    while (true) {
      _checkCancelled();
      final have = validator != null && await output.exists()
          ? await output.length()
          : 0;
      try {
        await _fetchToFile(url, output, have, stream, validator);
        break;
      } on _Retryable catch (error) {
        validator = (await _readState())?.mp4;
        final saved = validator != null && await output.exists()
            ? await output.length()
            : 0;
        if (saved > bestBytes) {
          bestBytes = saved;
          attempt = 0;
          onLoaded();
        }
        if (++attempt >= _attempts) throw _LinkRefused(error.reason);
        await _wait(attempt);
      }
    }
    await _deleteState();
    final bytes = await output.length();
    _report(bytes, bytes, videoHeight: _positiveHeight(stream.quality));
    return output;
  }

  /// Writes one response, appending only a verified range of the same file.
  Future<void> _fetchToFile(
    Uri url,
    File output,
    int have,
    OnlineStream stream,
    _Mp4Validator? validator,
  ) async {
    final response = await _send<ResponseBody>(
      url,
      ResponseType.stream,
      headers: {
        'Accept-Encoding': 'identity',
        if (have > 0) ...{'Range': 'bytes=$have-', 'If-Range': validator!.etag},
      },
    );
    final status = response.statusCode ?? 0;
    final body = response.data!;
    final contentRange = response.headers.value('content-range')?.trim();
    final etag = response.headers.value('etag')?.trim();
    final received = _isStrongEtag(etag)
        ? (
            etag: etag!,
            // Tags identify versions of one resource, not across URLs.
            uriHash: sha256
                .convert(
                  utf8.encode(
                    _responseUri(response).removeFragment().toString(),
                  ),
                )
                .toString(),
          )
        : null;
    if (status == 416 && have > 0) {
      await body.stream.drain<void>();
      if (received == validator &&
          contentRange?.toLowerCase() == 'bytes */$have') {
        return;
      }
      await _deleteState();
      throw const _Retryable('the server could not confirm the local file');
    }
    if (status != 200 && status != 206) {
      await body.stream.drain<void>();
      _checkStatus(status);
      throw _Retryable('HTTP $status did not include a video');
    }
    final range = status == 206 ? _mp4Range(contentRange) : null;
    final encoding = response.headers.value('content-encoding')?.toLowerCase();
    if ((encoding != null && encoding != 'identity') ||
        (status == 206 &&
            (range == null ||
                range.start != have ||
                (have > 0 && received != validator)))) {
      await body.stream.drain<void>();
      await _deleteState();
      throw const _Retryable('the server returned an incompatible range');
    }
    final total =
        range?.total ??
        int.tryParse(response.headers.value('content-length') ?? '') ??
        0;
    final end = range?.end ?? total;
    final sink = await output.open(mode: FileMode.append);
    var bytes = range?.start ?? 0;
    try {
      // A server that ignores Range sends the whole file again.
      await sink.truncate(bytes);
      await sink.setPosition(bytes);
      if (bytes == 0) {
        await _writeState(
          _State(
            format: stream.format.name,
            quality: stream.quality,
            pieces: 1,
            done: 0,
            bytes: 0,
            mp4: received,
          ),
        );
      }
      await for (final chunk in body.stream) {
        _checkCancelled();
        if (end > 0 && bytes + chunk.length > end) {
          throw const _Retryable('the body exceeded the declared length');
        }
        await sink.writeFrom(chunk);
        bytes += chunk.length;
        _report(
          bytes,
          total,
          chunk: true,
          videoHeight: _positiveHeight(stream.quality),
        );
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || _cancelled) throw const _Cancelled();
      throw _Retryable('${error.type}');
    } on Exception catch (error) {
      // A body that breaks off reaches here as it is, not as a
      // DioException: the connection, not the disk.
      if (error is! SocketException &&
          error is! HttpException &&
          error is! TlsException) {
        rethrow;
      }
      if (_cancelled) throw const _Cancelled();
      throw _Retryable('$error');
    } finally {
      await sink.close();
    }
    if (bytes == 0 || (total > 0 && bytes < total)) {
      throw const _Retryable('the body ended early');
    }
  }

  /// A segment or init piece, tried [_attempts] times; a link the server
  /// still refuses then is renewed.
  Future<List<int>> _fetchBytes(Uri url) async {
    for (var attempt = 1; ; attempt++) {
      try {
        final response = await _send<List<int>>(url, ResponseType.bytes);
        _checkStatus(response.statusCode ?? 0);
        final data = response.data;
        if (data == null || data.isEmpty) {
          throw const _Retryable('empty segment response');
        }
        return data;
      } on _Retryable catch (error) {
        if (attempt >= _attempts) throw _LinkRefused(error.reason);
        await _wait(attempt);
      }
    }
  }

  Future<({String text, Uri uri})> _fetchText(Uri url) async {
    for (var attempt = 1; ; attempt++) {
      try {
        final response = await _send<List<int>>(url, ResponseType.bytes);
        _checkStatus(response.statusCode ?? 0);
        return (
          text: utf8.decode(response.data ?? const [], allowMalformed: true),
          uri: _responseUri(response),
        );
      } on _Retryable catch (error) {
        if (attempt >= _attempts) throw _LinkRefused(error.reason);
        await _wait(attempt);
      }
    }
  }

  Future<Response<T>> _send<T>(
    Uri url,
    ResponseType type, {
    Map<String, String> headers = const {},
  }) async {
    _checkCancelled();
    try {
      return await downloader._dio.getUri<T>(
        url,
        cancelToken: _cancelToken,
        options: Options(
          responseType: type,
          headers: headers,
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || _cancelled) throw const _Cancelled();
      throw _Retryable('${error.type}');
    }
  }

  /// A refused link (403, 404, 410) is renewed at once; other failures
  /// are tried again first.
  void _checkStatus(int status) {
    if (status >= 200 && status < 300) return;
    if (status == 403 || status == 404 || status == 410) {
      throw _LinkRefused('HTTP $status');
    }
    throw _Retryable('HTTP $status');
  }

  Future<void> _wait(int attempt) =>
      _sleep(Duration(seconds: 1 << (attempt - 1)));

  /// Waits [delay], or less when the task is cancelled meanwhile.
  Future<void> _sleep(Duration delay) async {
    await Future.any([downloader._delay(delay), _cancelRequested.future]);
    _checkCancelled();
  }

  void _checkCancelled() {
    if (_cancelled) throw const _Cancelled();
  }

  /// [request] to the site, tried again while the network is down.
  Future<T> _whileOffline<T>(Future<T> Function() request) async {
    for (var attempt = 0; ; attempt++) {
      _checkCancelled();
      try {
        return await unlessCancelled(request(), _cancelRequested.future);
      } on Object catch (error) {
        if (_cancelled) throw const _Cancelled();
        if (!_isOffline(error) || attempt >= _offlineWaits.length) rethrow;
        developer.log(
          'The site is out of reach ($error); trying again.',
          name: 'iris.downloads.online',
        );
        await _sleep(Duration(seconds: _offlineWaits[attempt]));
      }
    }
  }

  /// When a [chunk] was last told; an mp4 body comes in chunks of a few
  /// KB, far more often than anyone reads it.
  DateTime? _chunkReportedAt;
  static const _chunkReportEvery = Duration(milliseconds: 250);

  void _report(int bytes, int total, {bool chunk = false, int? videoHeight}) {
    if (_progress.isClosed) return;
    if (chunk) {
      final now = downloader._now();
      final last = _chunkReportedAt;
      // A clock set back counts as time gone by, not as none.
      final since = last == null ? null : now.difference(last);
      if (since != null && !since.isNegative && since < _chunkReportEvery) {
        return;
      }
      _chunkReportedAt = now;
    }
    _progress.add(
      OnlineDownloadProgress(
        downloadedBytes: bytes,
        totalBytes: total,
        rateBytesPerSecond: _meter.add(bytes),
        videoHeight: videoHeight,
      ),
    );
  }

  File get _stateFile => File(path.join(directory.path, _stateFileName));

  Future<_State?> _readState() async {
    try {
      final json = jsonDecode(await _stateFile.readAsString());
      return json is Map<String, Object?> ? _State.fromJson(json) : null;
    } on Object {
      return null;
    }
  }

  Future<void> _writeState(_State state) =>
      _stateFile.writeAsString(jsonEncode(state.toJson()), flush: true);

  Future<void> _deleteState() async {
    if (await _stateFile.exists()) await _stateFile.delete();
  }
}

int? _positiveHeight(int height) => height > 0 ? height : null;

// A Location header can be relative to the previous redirect.
Uri _responseUri(Response<dynamic> response) => response.redirects.fold(
  response.requestOptions.uri,
  (base, redirect) => base.resolveUri(redirect.location),
);

typedef _Mp4Validator = ({String etag, String uriHash});

final _strongEtag = RegExp(r'^"[^"\x00-\x20\x7f]*"$');
final _rangeHeader = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$', caseSensitive: false);

bool _isStrongEtag(String? etag) => etag != null && _strongEtag.hasMatch(etag);

({int start, int end, int total})? _mp4Range(String? header) {
  final match = _rangeHeader.firstMatch(header ?? '');
  if (match == null) return null;
  final start = int.tryParse(match[1]!);
  final last = int.tryParse(match[2]!);
  final total = int.tryParse(match[3]!);
  if (start == null ||
      last == null ||
      total == null ||
      start > last ||
      last >= total) {
    return null;
  }
  return (start: start, end: last + 1, total: total);
}

/// Where the last run stopped.
class _State {
  const _State({
    required this.format,
    required this.quality,
    required this.pieces,
    required this.done,
    required this.bytes,
    this.playlistHash,
    this.mp4,
  });

  static _State? fromJson(Map<String, Object?> json) {
    final format = json['format'];
    final quality = json['quality'];
    final pieces = json['pieces'];
    final done = json['done'];
    final bytes = json['bytes'];
    final etag = json['mp4Etag'];
    final uriHash = json['mp4UriHash'];
    if (format is! String ||
        quality is! int ||
        pieces is! int ||
        done is! int ||
        bytes is! int ||
        pieces <= 0 ||
        done < 0 ||
        done > pieces ||
        bytes < 0) {
      return null;
    }
    return _State(
      format: format,
      quality: quality,
      pieces: pieces,
      done: done,
      bytes: bytes,
      playlistHash: json['playlistHash'] as String?,
      mp4: etag is String && _isStrongEtag(etag) && uriHash is String
          ? (etag: etag, uriHash: uriHash)
          : null,
    );
  }

  final String format;
  final int quality;

  /// Init piece and segments of an HLS episode; 1 for an mp4.
  final int pieces;
  final int done;
  final int bytes;
  final String? playlistHash;
  final _Mp4Validator? mp4;

  Map<String, Object?> toJson() => {
    'format': format,
    'quality': quality,
    'pieces': pieces,
    'done': done,
    'bytes': bytes,
    if (playlistHash != null) 'playlistHash': playlistHash,
    if (mp4 case final validator?) ...{
      'mp4Etag': validator.etag,
      'mp4UriHash': validator.uriHash,
    },
  };
}

/// Bytes a second over the last few seconds.
class _RateMeter {
  _RateMeter(this._now);

  static const _window = Duration(seconds: 3);

  final DateTime Function() _now;
  final _samples = <(DateTime, int)>[];

  int add(int bytes) {
    final now = _now();
    _samples
      ..add((now, bytes))
      ..removeWhere((sample) => now.difference(sample.$1) > _window);
    final (since, from) = _samples.first;
    final elapsed = now.difference(since).inMilliseconds;
    if (elapsed <= 0) return 0;
    return ((bytes - from) * 1000 / elapsed).round();
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// Worth another try of the same link.
class _Retryable implements Exception {
  const _Retryable(this.reason);

  final String reason;
}

/// The server will not give what the link points at: a fresh one is due.
class _LinkRefused implements Exception {
  const _LinkRefused(this.reason);

  final String reason;
}

/// A failure of the connection rather than an answer from the site.
bool _isOffline(Object error) => switch (error) {
  NetworkRequestException() ||
  SocketException() ||
  HttpException() ||
  TlsException() ||
  TimeoutException() => true,
  DioException(:final type) => switch (type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.unknown => true,
    _ => false,
  },
  _ => false,
};
