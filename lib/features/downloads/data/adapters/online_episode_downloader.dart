import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

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
  });

  final int downloadedBytes;
  final int totalBytes;
  final int rateBytesPerSecond;
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
  late final _meter = _RateMeter(downloader._now);

  @override
  Stream<OnlineDownloadProgress> get progress => _progress.stream;

  @override
  Future<File?> get done => _done.future;

  @override
  Future<void> cancel() async {
    _cancelled = true;
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
    final plan = await _playlist(Uri.parse(stream.url), stream.quality);
    final pieces = [?plan.init, ...plan.segments];
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
        await output.exists();
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
      _report(bytes, _estimate(plan, done, bytes, totalSeconds));
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
          ),
        );
        _report(bytes, _estimate(plan, done, bytes, totalSeconds));
      }
    } finally {
      await sink.close();
    }
    await _deleteState();
    _report(bytes, bytes);
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

  /// The media playlist of [url]; a master playlist gives the variant of
  /// [quality], or its best.
  Future<HlsPlan> _playlist(Uri url, int quality) async {
    final text = await _fetchText(url);
    final variant = HlsPlaylist.pickVariant(text, url, quality: quality);
    final plan = HlsPlaylist.parseMedia(
      variant == null ? text : await _fetchText(variant),
      variant ?? url,
    );
    if (plan == null) {
      throw const OnlineDownloadException(downloadNotDownloadableMessage);
    }
    return plan;
  }

  Future<File> _loadMp4(
    OnlineStream stream,
    _State? state,
    void Function() onLoaded,
  ) async {
    final output = File(path.join(directory.path, 'episode.mp4'));
    final resumable =
        state != null &&
        state.format == stream.format.name &&
        state.quality == stream.quality &&
        await output.exists();
    if (!resumable && await output.exists()) await output.delete();
    await _writeState(
      _State(
        format: stream.format.name,
        quality: stream.quality,
        pieces: 1,
        done: 0,
        bytes: 0,
      ),
    );

    var attempt = 0;
    while (true) {
      _checkCancelled();
      final have = await output.exists() ? await output.length() : 0;
      try {
        final total = await _fetchToFile(Uri.parse(stream.url), output, have);
        if (total > 0 && await output.length() < total) {
          throw const _Retryable('the body ended early');
        }
        break;
      } on _Retryable catch (error) {
        final length = await output.length();
        if (length > have) {
          attempt = 0;
          onLoaded();
        }
        if (++attempt >= _attempts) throw _LinkRefused(error.reason);
        await _wait(attempt);
      }
    }
    await _deleteState();
    final bytes = await output.length();
    _report(bytes, bytes);
    return output;
  }

  /// Appends [url] from byte [have] on to [output]; the whole size, or 0
  /// when the server does not say.
  Future<int> _fetchToFile(Uri url, File output, int have) async {
    final response = await _send<ResponseBody>(
      url,
      ResponseType.stream,
      headers: {if (have > 0) 'Range': 'bytes=$have-'},
    );
    final status = response.statusCode ?? 0;
    final body = response.data!;
    if (status == 416 && have > 0) {
      // Nothing past the end: the file is whole.
      await body.stream.drain<void>();
      return have;
    }
    _checkStatus(status);
    final partial = status == 206;
    final total = partial
        ? _totalFromRange(response.headers.value('content-range'))
        : int.tryParse(response.headers.value('content-length') ?? '') ?? 0;
    final sink = await output.open(mode: FileMode.append);
    var bytes = partial ? have : 0;
    try {
      // A server that ignores Range sends the whole file again.
      await sink.truncate(bytes);
      await sink.setPosition(bytes);
      await for (final chunk in body.stream) {
        _checkCancelled();
        await sink.writeFrom(chunk);
        bytes += chunk.length;
        _report(bytes, total, chunk: true);
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
    return total;
  }

  /// A segment or init piece, tried [_attempts] times; a link the server
  /// still refuses then is renewed.
  Future<List<int>> _fetchBytes(Uri url) async {
    for (var attempt = 1; ; attempt++) {
      try {
        final response = await _send<List<int>>(url, ResponseType.bytes);
        _checkStatus(response.statusCode ?? 0);
        return response.data ?? const [];
      } on _Retryable catch (error) {
        if (attempt >= _attempts) throw _LinkRefused(error.reason);
        await _wait(attempt);
      }
    }
  }

  Future<String> _fetchText(Uri url) async {
    for (var attempt = 1; ; attempt++) {
      try {
        final response = await _send<List<int>>(url, ResponseType.bytes);
        _checkStatus(response.statusCode ?? 0);
        return utf8.decode(response.data ?? const [], allowMalformed: true);
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

  Future<void> _wait(int attempt) async {
    await downloader._delay(Duration(seconds: 1 << (attempt - 1)));
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
        return await request();
      } on Object catch (error) {
        if (_cancelled) throw const _Cancelled();
        if (!_isOffline(error) || attempt >= _offlineWaits.length) rethrow;
        developer.log(
          'The site is out of reach ($error); trying again.',
          name: 'iris.downloads.online',
        );
        await downloader._delay(Duration(seconds: _offlineWaits[attempt]));
      }
    }
  }

  /// When a [chunk] was last told; an mp4 body comes in chunks of a few
  /// KB, far more often than anyone reads it.
  DateTime? _chunkReportedAt;
  static const _chunkReportEvery = Duration(milliseconds: 250);

  void _report(int bytes, int total, {bool chunk = false}) {
    if (_progress.isClosed) return;
    if (chunk) {
      final now = downloader._now();
      final last = _chunkReportedAt;
      if (last != null && now.difference(last) < _chunkReportEvery) return;
      _chunkReportedAt = now;
    }
    _progress.add(
      OnlineDownloadProgress(
        downloadedBytes: bytes,
        totalBytes: total,
        rateBytesPerSecond: _meter.add(bytes),
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

/// `bytes 100-999/1000` gives 1000; 0 when it says nothing usable.
int _totalFromRange(String? header) {
  final slash = header?.lastIndexOf('/') ?? -1;
  if (header == null || slash < 0) return 0;
  return int.tryParse(header.substring(slash + 1).trim()) ?? 0;
}

/// Where the last run stopped.
class _State {
  const _State({
    required this.format,
    required this.quality,
    required this.pieces,
    required this.done,
    required this.bytes,
  });

  static _State? fromJson(Map<String, Object?> json) {
    final format = json['format'];
    final quality = json['quality'];
    final pieces = json['pieces'];
    final done = json['done'];
    final bytes = json['bytes'];
    if (format is! String ||
        quality is! int ||
        pieces is! int ||
        done is! int ||
        bytes is! int) {
      return null;
    }
    return _State(
      format: format,
      quality: quality,
      pieces: pieces,
      done: done,
      bytes: bytes,
    );
  }

  final String format;
  final int quality;

  /// Init piece and segments of an HLS episode; 1 for an mp4.
  final int pieces;
  final int done;
  final int bytes;

  Map<String, Object?> toJson() => {
    'format': format,
    'quality': quality,
    'pieces': pieces,
    'done': done,
    'bytes': bytes,
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
  DioException(:final type) =>
    type != DioExceptionType.badResponse && type != DioExceptionType.cancel,
  _ => false,
};
