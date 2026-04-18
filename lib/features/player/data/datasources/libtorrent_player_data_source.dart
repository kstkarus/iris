import 'dart:developer' as developer;

import 'package:iris/features/player/data/adapters/libtorrent_engine_adapter.dart';
import 'package:iris/features/player/data/adapters/player_runtime_memory_adapter.dart';
import 'package:iris/features/player/data/exceptions/no_playable_video_exception.dart';
import 'package:iris/features/player/data/exceptions/torrent_metadata_unavailable_exception.dart';
import 'package:iris/features/player/data/models/playback_launch_update_model.dart';
import 'package:iris/features/player/data/models/playback_runtime_stats_model.dart';
import 'package:iris/features/player/data/models/prepared_playback_model.dart';
import 'package:iris/features/player/data/models/prepared_player_source_model.dart';
import 'package:iris/features/player/data/utils/playback_stream_probe.dart';
import 'package:iris/features/player/data/utils/player_debug_formatter.dart';

class LibtorrentPlayerDataSource {
  LibtorrentPlayerDataSource({
    required LibtorrentEngineAdapter engine,
    PlayerRuntimeMemoryAdapter memoryAdapter =
        const MethodChannelPlayerRuntimeMemoryAdapter(),
    PlaybackStreamProbe probe = const HttpPlaybackStreamProbe(),
    Duration statsPollInterval = const Duration(seconds: 1),
  }) : _engine = engine,
       _memoryAdapter = memoryAdapter,
       _statsPollInterval = statsPollInterval,
       _probe = probe;

  final LibtorrentEngineAdapter _engine;
  final PlayerRuntimeMemoryAdapter _memoryAdapter;
  final Duration _statsPollInterval;
  final PlaybackStreamProbe _probe;
  final Map<String, int> _streamIdsBySessionId = {};
  final Map<String, _PlaybackLaunchCancellation>
  _launchCancellationBySessionId = {};

  Future<PreparedPlayerSourceModel> prepareSource({
    required String magnet,
  }) async {
    developer.log(
      'Preparing playback for magnet=${redactMagnet(magnet)}',
      name: 'iris.player.datasource',
    );
    await _engine.initialize();

    final torrentId = _engine.addMagnet(magnet);
    try {
      await _engine.waitForMetadata(torrentId);
    } on TorrentMetadataUnavailableException {
      await _engine.disposeTorrent(torrentId);
      rethrow;
    }

    final files = _engine.getFiles(torrentId);
    developer.log(
      'Torrent file list: ${summarizeTorrentFiles(files)}',
      name: 'iris.player.datasource',
    );
    if (!files.any((file) => file.isStreamable)) {
      developer.log(
        'No streamable files found for torrentId=$torrentId',
        name: 'iris.player.datasource',
      );
      await _engine.disposeTorrent(torrentId);
      throw const NoPlayableVideoException();
    }

    developer.log(
      'Prepared source session. torrentId=$torrentId sessionId=$torrentId fileCount=${files.length}',
      name: 'iris.player.datasource',
    );

    return PreparedPlayerSourceModel(
      sessionId: torrentId.toString(),
      files: files,
    );
  }

  Stream<PlaybackLaunchUpdateModel> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) async* {
    final torrentId = int.tryParse(sessionId);
    if (torrentId == null) {
      developer.log(
        'Skipping playback start because sessionId is invalid: $sessionId',
        name: 'iris.player.datasource',
      );
      yield const PlaybackLaunchFailureUpdateModel(
        PlaybackLaunchFailureModel.unableToStart,
      );
      return;
    }

    developer.log(
      'Starting playback for prepared session. sessionId=$sessionId torrentId=$torrentId fileIndex=$fileIndex',
      name: 'iris.player.datasource',
    );

    if (_streamIdsBySessionId.containsKey(sessionId) ||
        _launchCancellationBySessionId.containsKey(sessionId)) {
      developer.log(
        'Skipping playback start because sessionId=$sessionId already has an active stream.',
        name: 'iris.player.datasource',
      );
      yield const PlaybackLaunchFailureUpdateModel(
        PlaybackLaunchFailureModel.unableToStart,
      );
      return;
    }

    final cancellation = _PlaybackLaunchCancellation();
    _launchCancellationBySessionId[sessionId] = cancellation;
    final stream = _engine.startStream(
      torrentId,
      fileIndex: fileIndex,
      maxCacheBytes: torrentStreamCacheBytes,
    );
    _streamIdsBySessionId[sessionId] = stream.streamId;

    try {
      final prepared = await _waitForPlayableHttpStream(
        stream.url,
        isCancelled: () => cancellation.isCancelled,
      );
      if (!prepared) {
        _completeLaunch(sessionId);
        return;
      }
      developer.log(
        'Playback stream prepared. torrentId=$torrentId sessionId=$sessionId streamId=${stream.streamId} url=${stream.url}',
        name: 'iris.player.datasource',
      );
      _launchCancellationBySessionId.remove(sessionId);
      yield PlaybackLaunchReadyUpdateModel(
        PreparedPlaybackModel(sessionId: sessionId, streamUrl: stream.url),
      );
    } catch (error, stackTrace) {
      if (cancellation.isCancelled) {
        _completeLaunch(sessionId);
        return;
      }
      developer.log(
        'Playback HTTP probe failed after stream startup. sessionId=$sessionId torrentId=$torrentId streamId=${stream.streamId}',
        name: 'iris.player.datasource',
        error: error,
        stackTrace: stackTrace,
      );
      yield const PlaybackLaunchFailureUpdateModel(
        PlaybackLaunchFailureModel.unableToStart,
      );
      _completeLaunch(sessionId);
    }
  }

  Stream<PlaybackRuntimeStatsModel> watchPlaybackStats({
    required String sessionId,
  }) async* {
    final streamId = _streamIdsBySessionId[sessionId];
    if (streamId == null) {
      return;
    }

    PlaybackRuntimeStatsModel? lastStats;
    while (_streamIdsBySessionId[sessionId] == streamId) {
      final streamStats = _engine.getPlaybackRuntimeStats(streamId);
      if (streamStats != null) {
        final appMemoryBytes = await _memoryAdapter.getAppMemoryBytes();
        final stats = streamStats.copyWith(
          appMemoryBytes: appMemoryBytes,
          clearAppMemoryBytes: appMemoryBytes == null,
        );
        if (stats != lastStats) {
          lastStats = stats;
          yield stats;
        }
      }

      await Future<void>.delayed(_statsPollInterval);
    }
  }

  Future<void> disposePlayback({required String sessionId}) async {
    final torrentId = int.tryParse(sessionId);
    if (torrentId == null) {
      developer.log(
        'Skipping playback dispose because sessionId is invalid: $sessionId',
        name: 'iris.player.datasource',
      );
      return;
    }

    final launchCancellation = _launchCancellationBySessionId.remove(sessionId);
    launchCancellation?.cancel();
    _streamIdsBySessionId.remove(sessionId);
    developer.log(
      'Disposing playback session. sessionId=$sessionId torrentId=$torrentId',
      name: 'iris.player.datasource',
    );
    await _engine.disposeTorrent(torrentId);
  }

  Future<bool> _waitForPlayableHttpStream(
    String url, {
    required bool Function() isCancelled,
  }) async {
    PlaybackProbeResult? lastResult;

    for (var attempt = 1; attempt <= 6; attempt++) {
      if (isCancelled()) {
        developer.log(
          'Stopping playback HTTP probe because launch was cancelled. url=$url attempt=$attempt',
          name: 'iris.player.datasource',
        );
        return false;
      }
      developer.log(
        'Running playback HTTP probe. attempt=$attempt url=$url',
        name: 'iris.player.datasource',
      );
      final result = await _probe.probe(url);
      lastResult = result;

      if (isCancelled()) {
        developer.log(
          'Stopping playback HTTP probe after probe completion because launch was cancelled. url=$url attempt=$attempt',
          name: 'iris.player.datasource',
        );
        return false;
      }

      if (result.looksLikePlayableMedia) {
        developer.log(
          'Playback HTTP probe recognized a playable media container. url=$url attempt=$attempt',
          name: 'iris.player.datasource',
        );
        return true;
      }

      if (attempt < 6) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    developer.log(
      'Playback HTTP probe could not confirm a playable media container. url=$url status=${lastResult?.statusCode} firstBytesHex=${lastResult == null ? 'none' : _toHex(lastResult.firstBytes)}',
      name: 'iris.player.datasource',
    );
    throw StateError(
      'Local torrent stream did not expose a playable media container.',
    );
  }

  void _completeLaunch(String sessionId) {
    _launchCancellationBySessionId.remove(sessionId);
    _streamIdsBySessionId.remove(sessionId);
  }
}

class _PlaybackLaunchCancellation {
  bool isCancelled = false;

  void cancel() {
    isCancelled = true;
  }
}

String _toHex(List<int> bytes) {
  if (bytes.isEmpty) {
    return 'empty';
  }

  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
}
