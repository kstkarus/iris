import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';

/// Streams torrents by default and plays completed downloads from disk.
///
/// Streaming sessions are numeric libtorrent torrent ids; download ids are
/// `<info-hash>-<file index>`, so the session id alone selects the backend.
class StreamingOrLocalPlayerRepository implements PlayerRepository {
  const StreamingOrLocalPlayerRepository({
    required PlayerRepository streaming,
    required PlayerRepository local,
  }) : _streaming = streaming,
       _local = local;

  final PlayerRepository _streaming;
  final PlayerRepository _local;

  @override
  Future<PreparedPlayerSource> prepareSource({required String magnet}) {
    return _streaming.prepareSource(magnet: magnet);
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) {
    return _backendFor(
      sessionId,
    ).startPlayback(sessionId: sessionId, fileIndex: fileIndex);
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return _backendFor(sessionId).watchPlaybackStats(sessionId: sessionId);
  }

  @override
  Future<void> stopPlayback({required String sessionId}) {
    return _backendFor(sessionId).stopPlayback(sessionId: sessionId);
  }

  @override
  Future<void> disposePlayback({required String sessionId}) {
    return _backendFor(sessionId).disposePlayback(sessionId: sessionId);
  }

  PlayerRepository _backendFor(String sessionId) {
    return int.tryParse(sessionId) != null ? _streaming : _local;
  }
}
