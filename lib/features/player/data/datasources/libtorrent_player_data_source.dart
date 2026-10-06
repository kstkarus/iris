import 'dart:async';
import 'dart:developer' as developer;

import 'package:iris/features/player/data/adapters/libtorrent_engine_adapter.dart';
import 'package:iris/features/player/data/adapters/player_runtime_memory_adapter.dart';
import 'package:iris/features/player/data/exceptions/no_playable_video_exception.dart';
import 'package:iris/features/player/data/models/playback_launch_update_model.dart';
import 'package:iris/features/player/data/models/playback_runtime_stats_model.dart';
import 'package:iris/features/player/data/models/prepared_playback_model.dart';
import 'package:iris/features/player/data/models/prepared_player_source_model.dart';
import 'package:iris/features/player/data/utils/playback_stream_probe.dart';
import 'package:iris/features/player/data/utils/player_debug_formatter.dart';
import 'package:iris/shared/torrent/torrent_activity_registry.dart';
import 'package:iris/shared/torrent/torrent_key.dart';

class LibtorrentPlayerDataSource {
  LibtorrentPlayerDataSource({
    required LibtorrentEngineAdapter engine,
    PlayerRuntimeMemoryAdapter memoryAdapter =
        const MethodChannelPlayerRuntimeMemoryAdapter(),
    PlaybackStreamProbe probe = const HttpPlaybackStreamProbe(),
    Duration statsPollInterval = const Duration(seconds: 1),
    TorrentActivityRegistry? activityRegistry,
  }) : _engine = engine,
       _activityRegistry = activityRegistry ?? TorrentActivityRegistry(),
       _memoryAdapter = memoryAdapter,
       _statsPollInterval = statsPollInterval,
       _probe = probe;

  final LibtorrentEngineAdapter _engine;
  final PlayerRuntimeMemoryAdapter _memoryAdapter;
  final Duration _statsPollInterval;
  final PlaybackStreamProbe _probe;
  final TorrentActivityRegistry _activityRegistry;
  final Map<String, String> _torrentKeysBySessionId = {};
  final Map<String, int> _streamIdsBySessionId = {};
  final Map<String, _PlaybackLaunchCancellation>
  _launchCancellationBySessionId = {};
  final Map<String, _BackgroundProbeToken> _probeTokensBySessionId = {};

  Future<PreparedPlayerSourceModel> prepareSource({
    required String magnet,
  }) async {
    developer.log(
      'Preparing playback for magnet=${redactMagnet(magnet)}',
      name: 'iris.player.datasource',
    );
    await _engine.initialize();

    final torrentKey = torrentKeyFromMagnet(magnet);
    // Must happen before addMagnet: a download of the same torrent releases
    // its native handle synchronously, otherwise libtorrent would hand us the
    // download's torrent and disposing playback would delete its files.
    _activityRegistry.acquireStreaming(torrentKey);
    final int torrentId;
    try {
      torrentId = _engine.addMagnet(magnet);
    } catch (_) {
      _activityRegistry.releaseStreaming(torrentKey);
      rethrow;
    }
    _torrentKeysBySessionId[torrentId.toString()] = torrentKey;
    try {
      await _engine.waitForMetadata(torrentId);
    } catch (_) {
      await disposePlayback(sessionId: torrentId.toString());
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
      await disposePlayback(sessionId: torrentId.toString());
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
      _launchHttpProbeInBackground(
        sessionId: sessionId,
        url: stream.url,
        isLaunchCancelled: () => cancellation.isCancelled,
      );
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

  /// Stops the session's stream and keeps the torrent for the next file.
  Future<void> stopPlayback({required String sessionId}) async {
    _launchCancellationBySessionId.remove(sessionId)?.cancel();
    _probeTokensBySessionId.remove(sessionId)?.cancel();
    final streamId = _streamIdsBySessionId.remove(sessionId);
    if (streamId == null) return;
    developer.log(
      'Stopping playback stream. sessionId=$sessionId streamId=$streamId',
      name: 'iris.player.datasource',
    );
    _engine.stopStream(streamId);
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
    final probeToken = _probeTokensBySessionId.remove(sessionId);
    probeToken?.cancel();
    _streamIdsBySessionId.remove(sessionId);
    developer.log(
      'Disposing playback session. sessionId=$sessionId torrentId=$torrentId',
      name: 'iris.player.datasource',
    );
    await _engine.disposeTorrent(torrentId);
    final torrentKey = _torrentKeysBySessionId.remove(sessionId);
    if (torrentKey != null) _activityRegistry.releaseStreaming(torrentKey);
  }

  void _launchHttpProbeInBackground({
    required String sessionId,
    required String url,
    required bool Function() isLaunchCancelled,
  }) {
    final previousToken = _probeTokensBySessionId.remove(sessionId);
    previousToken?.cancel();

    final token = _BackgroundProbeToken();
    _probeTokensBySessionId[sessionId] = token;
    unawaited(
      _runHttpProbeInBackground(
        sessionId: sessionId,
        url: url,
        token: token,
        isLaunchCancelled: isLaunchCancelled,
      ),
    );
  }

  Future<void> _runHttpProbeInBackground({
    required String sessionId,
    required String url,
    required _BackgroundProbeToken token,
    required bool Function() isLaunchCancelled,
  }) async {
    PlaybackProbeResult? lastResult;

    try {
      for (var attempt = 1; attempt <= 6; attempt++) {
        if (_shouldStopProbe(sessionId, token, isLaunchCancelled)) {
          developer.log(
            'Stopping background playback HTTP probe because the session is no longer active. sessionId=$sessionId url=$url attempt=$attempt',
            name: 'iris.player.datasource',
          );
          return;
        }
        developer.log(
          'Running background playback HTTP probe. sessionId=$sessionId attempt=$attempt url=$url',
          name: 'iris.player.datasource',
        );
        final result = await _probe.probe(url);
        lastResult = result;

        if (_shouldStopProbe(sessionId, token, isLaunchCancelled)) {
          developer.log(
            'Ignoring completed background playback HTTP probe because the session is no longer active. sessionId=$sessionId url=$url attempt=$attempt',
            name: 'iris.player.datasource',
          );
          return;
        }

        if (result.looksLikePlayableMedia) {
          developer.log(
            'Background playback HTTP probe recognized a playable media container. sessionId=$sessionId url=$url attempt=$attempt',
            name: 'iris.player.datasource',
          );
          return;
        }

        if (attempt < 6) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }

      if (_shouldStopProbe(sessionId, token, isLaunchCancelled)) {
        return;
      }

      developer.log(
        'Background playback HTTP probe could not confirm a playable media container. sessionId=$sessionId url=$url status=${lastResult?.statusCode} firstBytesHex=${lastResult == null ? 'none' : _toHex(lastResult.firstBytes)}',
        name: 'iris.player.datasource',
      );
    } catch (error, stackTrace) {
      if (_shouldStopProbe(sessionId, token, isLaunchCancelled)) {
        return;
      }
      developer.log(
        'Background playback HTTP probe failed unexpectedly. sessionId=$sessionId url=$url',
        name: 'iris.player.datasource',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (identical(_probeTokensBySessionId[sessionId], token)) {
        _probeTokensBySessionId.remove(sessionId);
      }
    }
  }

  bool _shouldStopProbe(
    String sessionId,
    _BackgroundProbeToken token,
    bool Function() isLaunchCancelled,
  ) {
    return token.isCancelled ||
        isLaunchCancelled() ||
        _streamIdsBySessionId[sessionId] == null ||
        !identical(_probeTokensBySessionId[sessionId], token);
  }

  void _completeLaunch(String sessionId) {
    _launchCancellationBySessionId.remove(sessionId);
    final probeToken = _probeTokensBySessionId.remove(sessionId);
    probeToken?.cancel();
    _streamIdsBySessionId.remove(sessionId);
  }
}

class _PlaybackLaunchCancellation {
  bool isCancelled = false;

  void cancel() {
    isCancelled = true;
  }
}

class _BackgroundProbeToken {
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
