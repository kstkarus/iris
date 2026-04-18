import 'dart:developer' as developer;

import 'package:iris/features/player/data/adapters/libtorrent_engine_adapter.dart';
import 'package:iris/features/player/data/adapters/player_runtime_memory_adapter.dart';
import 'package:iris/features/player/data/exceptions/startup_buffer_unavailable_exception.dart';
import 'package:iris/features/player/data/exceptions/no_playable_video_exception.dart';
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

  Future<PreparedPlayerSourceModel> prepareSource({
    required String magnet,
  }) async {
    developer.log(
      'Preparing playback for magnet=${redactMagnet(magnet)}',
      name: 'iris.player.datasource',
    );
    await _engine.initialize();

    final torrentId = _engine.addMagnet(magnet);
    await _engine.waitForMetadata(torrentId);

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

    final stream = _engine.startStream(torrentId, fileIndex: fileIndex);
    _streamIdsBySessionId[sessionId] = stream.streamId;
    PlaybackLaunchProgressUpdateModel? lastProgressUpdate;
    try {
      await for (final progress in _engine.waitForStreamReady(
        stream.streamId,
      )) {
        final progressUpdate = PlaybackLaunchProgressUpdateModel(progress);
        lastProgressUpdate = progressUpdate;
        yield progressUpdate;
      }
    } on StartupBufferUnavailableException catch (error) {
      developer.log(
        'Torrent stream could not gather enough startup buffer. sessionId=$sessionId torrentId=$torrentId streamId=${stream.streamId}',
        name: 'iris.player.datasource',
      );
      final failureProgressUpdate = PlaybackLaunchProgressUpdateModel(
        error.progress,
      );
      if (failureProgressUpdate != lastProgressUpdate) {
        yield failureProgressUpdate;
      }
      yield const PlaybackLaunchFailureUpdateModel(
        PlaybackLaunchFailureModel.unableToPrepareStartupBuffer,
      );
      _streamIdsBySessionId.remove(sessionId);
      return;
    } catch (error, stackTrace) {
      developer.log(
        'Playback startup failed unexpectedly before HTTP probe. sessionId=$sessionId torrentId=$torrentId streamId=${stream.streamId}',
        name: 'iris.player.datasource',
        error: error,
        stackTrace: stackTrace,
      );
      yield const PlaybackLaunchFailureUpdateModel(
        PlaybackLaunchFailureModel.unableToStart,
      );
      _streamIdsBySessionId.remove(sessionId);
      return;
    }

    try {
      await _waitForPlayableHttpStream(stream.url);
      developer.log(
        'Playback stream prepared. torrentId=$torrentId sessionId=$sessionId streamId=${stream.streamId} url=${stream.url}',
        name: 'iris.player.datasource',
      );
      yield PlaybackLaunchReadyUpdateModel(
        PreparedPlaybackModel(sessionId: sessionId, streamUrl: stream.url),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Playback HTTP probe failed after stream startup. sessionId=$sessionId torrentId=$torrentId streamId=${stream.streamId}',
        name: 'iris.player.datasource',
        error: error,
        stackTrace: stackTrace,
      );
      yield const PlaybackLaunchFailureUpdateModel(
        PlaybackLaunchFailureModel.unableToStart,
      );
      _streamIdsBySessionId.remove(sessionId);
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

    _streamIdsBySessionId.remove(sessionId);
    developer.log(
      'Disposing playback session. sessionId=$sessionId torrentId=$torrentId',
      name: 'iris.player.datasource',
    );
    await _engine.disposeTorrent(torrentId);
  }

  Future<void> _waitForPlayableHttpStream(String url) async {
    PlaybackProbeResult? lastResult;

    for (var attempt = 1; attempt <= 6; attempt++) {
      developer.log(
        'Running playback HTTP probe. attempt=$attempt url=$url',
        name: 'iris.player.datasource',
      );
      final result = await _probe.probe(url);
      lastResult = result;

      if (result.looksLikePlayableMedia) {
        developer.log(
          'Playback HTTP probe recognized a playable media container. url=$url attempt=$attempt',
          name: 'iris.player.datasource',
        );
        return;
      }

      await Future<void>.delayed(const Duration(seconds: 1));
    }

    developer.log(
      'Playback HTTP probe could not confirm a playable media container. url=$url status=${lastResult?.statusCode} firstBytesHex=${lastResult == null ? 'none' : _toHex(lastResult.firstBytes)}',
      name: 'iris.player.datasource',
    );
    throw StateError(
      'Local torrent stream did not expose a playable media container.',
    );
  }
}

String _toHex(List<int> bytes) {
  if (bytes.isEmpty) {
    return 'empty';
  }

  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
}
