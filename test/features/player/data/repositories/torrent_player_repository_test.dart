import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/data/adapters/libtorrent_engine_adapter.dart';
import 'package:iris/features/player/data/datasources/libtorrent_player_data_source.dart';
import 'package:iris/features/player/data/models/playback_launch_progress_model.dart';
import 'package:iris/features/player/data/models/playback_runtime_stats_model.dart';
import 'package:iris/features/player/data/models/playback_launch_update_model.dart';
import 'package:iris/features/player/data/models/playback_stream_descriptor.dart';
import 'package:iris/features/player/data/models/prepared_playback_model.dart';
import 'package:iris/features/player/data/models/prepared_player_source_model.dart';
import 'package:iris/features/player/data/models/torrent_file_descriptor.dart';
import 'package:iris/features/player/data/repositories/torrent_player_repository.dart';
import 'package:iris/features/player/domain/entities/player_launch_failure.dart';
import 'package:iris/features/player/domain/entities/player_launch_progress.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';

void main() {
  test(
    'maps internal launch progress into readiness progress for the player UI',
    () async {
      final repository = TorrentPlayerRepository(
        dataSource: _FakePlayerDataSource(
          launchUpdates: [
            const PlaybackLaunchProgressUpdateModel(
              PlaybackLaunchProgressModel(
                bufferProgress: 0.25,
                downloadRateBytesPerSecond: 2048,
                stage: PlaybackLaunchStageModel.buffering,
              ),
            ),
            const PlaybackLaunchReadyUpdateModel(
              PreparedPlaybackModel(
                sessionId: '42',
                streamUrl: 'http://127.0.0.1:8080/stream/2',
              ),
            ),
          ],
        ),
      );

      final updates = await repository
          .startPlayback(sessionId: '42', fileIndex: 2)
          .toList();

      expect(updates, [
        const PlayerLaunchProgressUpdate(
          PlayerLaunchProgress(
            bufferProgress: 0.5,
            downloadRateBytesPerSecond: 2048,
            stage: PlayerLaunchStage.preparing,
          ),
        ),
        const PlayerLaunchReadyUpdate(
          PlayerSession(
            sessionId: '42',
            streamUrl: 'http://127.0.0.1:8080/stream/2',
          ),
        ),
      ]);
    },
  );

  test(
    'maps startup buffer failure into domain startup buffer failure',
    () async {
      final repository = TorrentPlayerRepository(
        dataSource: _FakePlayerDataSource(
          launchUpdates: const [
            PlaybackLaunchFailureUpdateModel(
              PlaybackLaunchFailureModel.unableToPrepareStartupBuffer,
            ),
          ],
        ),
      );

      final updates = await repository
          .startPlayback(sessionId: '42', fileIndex: 2)
          .toList();

      expect(updates, const [
        PlayerLaunchFailureUpdate(
          PlayerLaunchFailure.unableToPrepareStartupBuffer,
        ),
      ]);
    },
  );

  test(
    'maps unexpected datasource errors into generic domain launch failure',
    () async {
      final repository = TorrentPlayerRepository(
        dataSource: _FakePlayerDataSource(throwOnStartPlayback: true),
      );

      final updates = await repository
          .startPlayback(sessionId: '42', fileIndex: 2)
          .toList();

      expect(updates, const [
        PlayerLaunchFailureUpdate(PlayerLaunchFailure.unableToStart),
      ]);
    },
  );

  test('maps runtime playback stats into domain playback stats', () async {
    final repository = TorrentPlayerRepository(
      dataSource: _FakePlayerDataSource(
        runtimeStats: const [
          PlaybackRuntimeStatsModel(
            downloadRateBytesPerSecond: 3145728,
            appMemoryBytes: 134217728,
            activePeers: 42,
            bufferSeconds: 18,
            bufferPieces: 24,
            readaheadWindow: 32,
          ),
        ],
      ),
    );

    final stats = await repository.watchPlaybackStats(sessionId: '42').first;

    expect(
      stats,
      const PlayerPlaybackStats(
        downloadRateBytesPerSecond: 3145728,
        appMemoryBytes: 134217728,
        activePeers: 42,
        bufferSeconds: 18,
        bufferPieces: 24,
        readaheadWindow: 32,
      ),
    );
  });
}

class _FakePlayerDataSource extends LibtorrentPlayerDataSource {
  _FakePlayerDataSource({
    this.launchUpdates = const [],
    this.throwOnStartPlayback = false,
    this.runtimeStats = const [],
  }) : super(engine: _UnusedLibtorrentEngineAdapter());

  final List<PlaybackLaunchUpdateModel> launchUpdates;
  final bool throwOnStartPlayback;
  final List<PlaybackRuntimeStatsModel> runtimeStats;

  @override
  Future<PreparedPlayerSourceModel> prepareSource({required String magnet}) {
    throw UnimplementedError();
  }

  @override
  Stream<PlaybackLaunchUpdateModel> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) async* {
    if (throwOnStartPlayback) {
      throw Exception('boom');
    }

    for (final update in launchUpdates) {
      yield update;
    }
  }

  @override
  Stream<PlaybackRuntimeStatsModel> watchPlaybackStats({
    required String sessionId,
  }) async* {
    for (final stats in runtimeStats) {
      yield stats;
    }
  }
}

class _UnusedLibtorrentEngineAdapter implements LibtorrentEngineAdapter {
  @override
  int addMagnet(String magnet) {
    throw UnimplementedError();
  }

  @override
  Future<void> disposeTorrent(int torrentId) async {
    throw UnimplementedError();
  }

  @override
  List<TorrentFileDescriptor> getFiles(int torrentId) {
    throw UnimplementedError();
  }

  @override
  Future<void> initialize() async {
    throw UnimplementedError();
  }

  @override
  PlaybackStreamDescriptor startStream(
    int torrentId, {
    required int fileIndex,
    int maxCacheBytes = 0,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> waitForMetadata(int torrentId) async {
    throw UnimplementedError();
  }

  @override
  Stream<PlaybackLaunchProgressModel> waitForStreamReady(
    int streamId, {
    required bool Function() isCancelled,
  }) {
    throw UnimplementedError();
  }

  @override
  PlaybackRuntimeStatsModel? getPlaybackRuntimeStats(int streamId) {
    throw UnimplementedError();
  }
}
