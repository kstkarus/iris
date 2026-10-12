import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';

abstract interface class PlayerRepository {
  /// [cancelled] completes when the caller no longer wants the source; the
  /// preparation then stops and releases what it holds.
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  });

  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  });

  /// A fresh link to the file [session] plays, when its link may have
  /// expired: online video servers issue links that do. Null when this
  /// backend's links never expire (a torrent's local stream, a download).
  Future<PlayerSession?> renewSession(PlayerSession session);

  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId});

  /// Stops the current file's stream but keeps the torrent, so another
  /// file of it can be played next.
  Future<void> stopPlayback({required String sessionId});

  Future<void> disposePlayback({required String sessionId});
}
