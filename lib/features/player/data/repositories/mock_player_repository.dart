import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';

class MockPlayerRepository implements PlayerRepository {
  @override
  Future<void> stopPlayback({required String sessionId}) async {}

  const MockPlayerRepository();

  @override
  Future<void> disposePlayback({required String sessionId}) async {}

  @override
  Future<PreparedPlayerSource> prepareSource({required String magnet}) async {
    return const PreparedPlayerSource(
      sessionId: 'mock-session',
      files: [
        PlayerVideoFile(
          index: 0,
          name: 'episode-01.mkv',
          size: 734003200,
          extension: 'mkv',
        ),
        PlayerVideoFile(
          index: 1,
          name: 'episode-02.mkv',
          size: 754974720,
          extension: 'mkv',
        ),
      ],
    );
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) async* {
    yield const PlayerLaunchReadyUpdate(
      PlayerSession(
        sessionId: 'mock-session',
        streamUrl: 'http://127.0.0.1/mock/stream',
      ),
    );
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return Stream.value(
      const PlayerPlaybackStats(
        downloadRateBytesPerSecond: 1572864,
        appMemoryBytes: 134217728,
        activePeers: 42,
        bufferSeconds: 16,
        bufferPieces: 22,
        readaheadWindow: 30,
      ),
    );
  }
}
