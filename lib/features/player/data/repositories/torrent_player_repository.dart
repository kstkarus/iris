import 'dart:developer' as developer;

import 'package:iris/features/player/data/datasources/libtorrent_player_data_source.dart';
import 'package:iris/features/player/data/exceptions/no_playable_video_exception.dart';
import 'package:iris/features/player/data/models/playback_launch_progress_model.dart';
import 'package:iris/features/player/data/models/playback_runtime_stats_model.dart';
import 'package:iris/features/player/data/models/playback_launch_update_model.dart';
import 'package:iris/features/player/data/models/torrent_file_descriptor.dart';
import 'package:iris/features/player/domain/entities/player_launch_failure.dart';
import 'package:iris/features/player/domain/entities/player_launch_progress.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/player_buffer_policy.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';

class TorrentPlayerRepository implements PlayerRepository {
  const TorrentPlayerRepository({required this.dataSource});

  final LibtorrentPlayerDataSource dataSource;

  @override
  Future<void> disposePlayback({required String sessionId}) {
    return dataSource.disposePlayback(sessionId: sessionId);
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({
    required String sessionId,
  }) async* {
    try {
      await for (final stats in dataSource.watchPlaybackStats(
        sessionId: sessionId,
      )) {
        yield _mapPlaybackStats(stats);
      }
    } catch (error, stackTrace) {
      developer.log(
        'Repository failed to map playback runtime stats.',
        name: 'iris.player.repository',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<PreparedPlayerSource> prepareSource({required String magnet}) async {
    final preparedSource = await dataSource.prepareSource(magnet: magnet);
    final files =
        preparedSource.files
            .where(_isSupportedVideoFile)
            .map(
              (file) => PlayerVideoFile(
                index: file.index,
                name: file.name,
                size: file.size,
                extension: _extractExtension(file.name),
              ),
            )
            .toList()
          ..sort((left, right) => left.index.compareTo(right.index));

    if (files.isEmpty) {
      await dataSource.disposePlayback(sessionId: preparedSource.sessionId);
      throw const NoPlayableVideoException();
    }

    return PreparedPlayerSource(
      sessionId: preparedSource.sessionId,
      files: files,
    );
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) async* {
    try {
      await for (final update in dataSource.startPlayback(
        sessionId: sessionId,
        fileIndex: fileIndex,
      )) {
        switch (update) {
          case PlaybackLaunchProgressUpdateModel(:final progress):
            yield PlayerLaunchProgressUpdate(_mapLaunchProgress(progress));
          case PlaybackLaunchReadyUpdateModel(:final playback):
            yield PlayerLaunchReadyUpdate(
              PlayerSession(
                sessionId: playback.sessionId,
                streamUrl: playback.streamUrl,
              ),
            );
          case PlaybackLaunchFailureUpdateModel(:final failure):
            yield PlayerLaunchFailureUpdate(_mapLaunchFailure(failure));
        }
      }
    } catch (error, stackTrace) {
      developer.log(
        'Repository failed to map playback launch update stream.',
        name: 'iris.player.repository',
        error: error,
        stackTrace: stackTrace,
      );
      yield const PlayerLaunchFailureUpdate(PlayerLaunchFailure.unableToStart);
    }
  }
}

PlayerLaunchProgress _mapLaunchProgress(PlaybackLaunchProgressModel progress) {
  return PlayerLaunchProgress(
    bufferProgress: _mapReadinessProgress(progress.bufferProgress),
    downloadRateBytesPerSecond: progress.downloadRateBytesPerSecond,
    stage: switch (progress.stage) {
      PlaybackLaunchStageModel.buffering => PlayerLaunchStage.preparing,
      PlaybackLaunchStageModel.extendedBuffering =>
        PlayerLaunchStage.waitingForBuffer,
    },
  );
}

double _mapReadinessProgress(double rawBufferProgress) {
  final normalized = rawBufferProgress / playerStartupReadyBufferProgress;
  return normalized.clamp(0.0, 1.0);
}

PlayerPlaybackStats _mapPlaybackStats(PlaybackRuntimeStatsModel stats) {
  return PlayerPlaybackStats(
    downloadRateBytesPerSecond: stats.downloadRateBytesPerSecond,
    appMemoryBytes: stats.appMemoryBytes,
    activePeers: stats.activePeers,
    bufferSeconds: stats.bufferSeconds,
    bufferPieces: stats.bufferPieces,
    readaheadWindow: stats.readaheadWindow,
  );
}

PlayerLaunchFailure _mapLaunchFailure(PlaybackLaunchFailureModel failure) {
  return switch (failure) {
    PlaybackLaunchFailureModel.unableToStart =>
      PlayerLaunchFailure.unableToStart,
    PlaybackLaunchFailureModel.unableToPrepareStartupBuffer =>
      PlayerLaunchFailure.unableToPrepareStartupBuffer,
  };
}

const _supportedVideoExtensions = {
  'mkv',
  'mp4',
  'webm',
  'avi',
  'mov',
  'm4v',
  'ts',
  'm2ts',
};

bool _isSupportedVideoFile(TorrentFileDescriptor file) {
  return file.isStreamable &&
      _supportedVideoExtensions.contains(_extractExtension(file.name));
}

String _extractExtension(String name) {
  final dotIndex = name.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == name.length - 1) {
    return '';
  }

  return name.substring(dotIndex + 1).toLowerCase();
}
