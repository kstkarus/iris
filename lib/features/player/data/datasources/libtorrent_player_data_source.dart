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

/// Player sessions over libtorrent.
///
/// libtorrent keeps one native torrent per info-hash, whatever id an add
/// returns, so sessions of the same torrent (a player page closing while the
/// next one opens) share one torrent here: it is removed, with its files,
/// only when the last of its sessions is disposed.
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
  final Map<String, _SharedTorrent> _torrentsByKey = {};
  final Map<String, _SharedTorrent> _torrentsBySessionId = {};

  /// Numeric: the player routes numeric session ids to streaming.
  int _lastSessionId = 0;
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

    final torrent = _acquireTorrent(magnet);
    final sessionId = '${++_lastSessionId}';
    _torrentsBySessionId[sessionId] = torrent;
    torrent.sessionIds.add(sessionId);
    final torrentId = torrent.torrentId;
    try {
      await torrent.metadata;
    } catch (_) {
      await disposePlayback(sessionId: sessionId);
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
      await disposePlayback(sessionId: sessionId);
      throw const NoPlayableVideoException();
    }

    developer.log(
      'Prepared source session. torrentId=$torrentId sessionId=$sessionId '
      'sessionsOnTorrent=${torrent.sessionIds.length} '
      'fileCount=${files.length}',
      name: 'iris.player.datasource',
    );

    return PreparedPlayerSourceModel(sessionId: sessionId, files: files);
  }

  /// The torrent of [magnet]: the one a live session still holds, or a new
  /// one. A download of the same torrent steps aside before it is added.
  _SharedTorrent _acquireTorrent(String magnet) {
    final torrentKey = torrentKeyFromMagnet(magnet);
    final existing = _torrentsByKey[torrentKey];
    if (existing != null) {
      developer.log(
        'Reusing the torrent of a live session. '
        'torrentId=${existing.torrentId} '
        'sessionsOnTorrent=${existing.sessionIds.length}',
        name: 'iris.player.datasource',
      );
      return existing;
    }

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
    final metadata = _engine.waitForMetadata(torrentId);
    // Each preparing session awaits it; this only keeps a failure that no
    // session awaits any more from being reported as unhandled.
    metadata.ignore();
    final torrent = _SharedTorrent(
      torrentKey: torrentKey,
      torrentId: torrentId,
      metadata: metadata,
    );
    _torrentsByKey[torrentKey] = torrent;
    return torrent;
  }

  Stream<PlaybackLaunchUpdateModel> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) async* {
    final torrent = _torrentsBySessionId[sessionId];
    if (torrent == null) {
      developer.log(
        'Skipping playback start because the session is unknown or '
        'disposed: $sessionId',
        name: 'iris.player.datasource',
      );
      yield const PlaybackLaunchFailureUpdateModel(
        PlaybackLaunchFailureModel.unableToStart,
      );
      return;
    }
    final torrentId = torrent.torrentId;

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

    _stopOtherStreamsOnTorrent(torrent, sessionId: sessionId);
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

  /// The end of a stream resets the whole torrent's piece priorities, which
  /// would starve a newer stream of the same torrent. So an older session's
  /// stream stops before a new one starts; in practice that session's page
  /// is already closing.
  void _stopOtherStreamsOnTorrent(
    _SharedTorrent torrent, {
    required String sessionId,
  }) {
    for (final otherSessionId in torrent.sessionIds) {
      if (otherSessionId == sessionId) continue;
      final streamId = _streamIdsBySessionId[otherSessionId];
      if (streamId == null) continue;
      developer.log(
        'Stopping the stream of an older session on the same torrent. '
        'sessionId=$otherSessionId streamId=$streamId '
        'newSessionId=$sessionId',
        name: 'iris.player.datasource',
      );
      _releaseStream(otherSessionId);
      _engine.stopStream(streamId);
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
    final streamId = _releaseStream(sessionId);
    if (streamId == null) return;
    developer.log(
      'Stopping playback stream. sessionId=$sessionId streamId=$streamId',
      name: 'iris.player.datasource',
    );
    _engine.stopStream(streamId);
  }

  /// Ends the session: stops its stream and lets go of its torrent, which
  /// is removed with its files once no session holds it. An unknown or
  /// already disposed session is left alone.
  Future<void> disposePlayback({required String sessionId}) async {
    final torrent = _torrentsBySessionId.remove(sessionId);
    final streamId = _releaseStream(sessionId);
    if (torrent == null) {
      developer.log(
        'Skipping playback dispose because the session is unknown or '
        'already disposed: $sessionId',
        name: 'iris.player.datasource',
      );
      return;
    }

    torrent.sessionIds.remove(sessionId);
    developer.log(
      'Disposing playback session. sessionId=$sessionId '
      'torrentId=${torrent.torrentId} '
      'sessionsLeftOnTorrent=${torrent.sessionIds.length}',
      name: 'iris.player.datasource',
    );
    if (torrent.sessionIds.isNotEmpty) {
      if (streamId != null) _engine.stopStream(streamId);
      return;
    }

    _torrentsByKey.remove(torrent.torrentKey);
    try {
      // Also stops whatever still streams from it.
      await _engine.disposeTorrent(torrent.torrentId);
    } finally {
      // A failed removal must not keep a download of it waiting for good.
      _activityRegistry.releaseStreaming(torrent.torrentKey);
    }
  }

  /// Forgets the session's stream and its launch and probe; the caller
  /// stops the native stream. Returns the stream's id, if it had one.
  int? _releaseStream(String sessionId) {
    _launchCancellationBySessionId.remove(sessionId)?.cancel();
    _probeTokensBySessionId.remove(sessionId)?.cancel();
    return _streamIdsBySessionId.remove(sessionId);
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

/// One native torrent and the sessions playing from it.
class _SharedTorrent {
  _SharedTorrent({
    required this.torrentKey,
    required this.torrentId,
    required this.metadata,
  });

  final String torrentKey;
  final int torrentId;

  /// Awaited by every session that prepares this torrent.
  final Future<void> metadata;
  final Set<String> sessionIds = {};
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
