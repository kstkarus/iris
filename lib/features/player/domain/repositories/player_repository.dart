import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';

abstract interface class PlayerRepository {
  Future<PreparedPlayerSource> prepareSource({required String magnet});

  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  });

  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId});

  /// Stops the current file's stream but keeps the torrent, so another
  /// file of it can be played next.
  Future<void> stopPlayback({required String sessionId});

  Future<void> disposePlayback({required String sessionId});
}
