import 'dart:developer' as developer;

import 'package:iris/features/player/data/datasources/libtorrent_player_data_source.dart';
import 'package:iris/features/player/domain/entities/no_playable_video_exception.dart';
import 'package:iris/features/player/data/models/playback_runtime_stats_model.dart';
import 'package:iris/features/player/data/models/playback_launch_update_model.dart';
import 'package:iris/features/player/data/models/torrent_file_descriptor.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/shared/torrent/video_file_extensions.dart';

class TorrentPlayerRepository implements PlayerRepository {
  const TorrentPlayerRepository({required this.dataSource});

  final LibtorrentPlayerDataSource dataSource;

  @override
  Future<void> stopPlayback({required String sessionId}) {
    return dataSource.stopPlayback(sessionId: sessionId);
  }

  @override
  Future<void> disposePlayback({required String sessionId}) {
    return dataSource.disposePlayback(sessionId: sessionId);
  }

  /// The local stream's address lasts as long as the session.
  @override
  Future<PlayerSession?> renewSession(PlayerSession session) async => null;

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
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    final preparedSource = await dataSource.prepareSource(
      magnet: magnet,
      cancelled: cancelled,
    );
    final files =
        preparedSource.files
            .where(_isSupportedVideoFile)
            .map(
              (file) => PlayerVideoFile(
                index: file.index,
                name: file.name,
                size: file.size,
                extension: videoFileExtension(file.name),
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
          case PlaybackLaunchReadyUpdateModel(:final playback):
            yield PlayerLaunchReadyUpdate(
              PlayerSession(
                sessionId: playback.sessionId,
                streamUrl: playback.streamUrl,
              ),
            );
          case PlaybackLaunchFailureUpdateModel():
            yield const PlayerLaunchFailureUpdate();
        }
      }
    } catch (error, stackTrace) {
      developer.log(
        'Repository failed to map playback launch update stream.',
        name: 'iris.player.repository',
        error: error,
        stackTrace: stackTrace,
      );
      yield const PlayerLaunchFailureUpdate();
    }
  }
}

PlayerPlaybackStats _mapPlaybackStats(PlaybackRuntimeStatsModel stats) {
  return PlayerPlaybackStats(
    downloadRateBytesPerSecond: stats.downloadRateBytesPerSecond,
    appMemoryBytes: stats.appMemoryBytes,
    activePeers: stats.activePeers,
    bufferSeconds: stats.bufferSeconds,
    bufferPieces: stats.bufferPieces,
    readaheadWindow: stats.readaheadWindow,
    isTorrent: true,
  );
}

bool _isSupportedVideoFile(TorrentFileDescriptor file) {
  return file.isStreamable && isVideoFileName(file.name);
}
