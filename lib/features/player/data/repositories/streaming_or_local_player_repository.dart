import 'package:iris/features/online_sources/domain/entities/online_source_link.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';

/// Streams torrents by default, plays online releases from their video
/// servers and completed downloads from disk.
///
/// Streaming sessions are numeric libtorrent torrent ids, online sessions
/// are the release's [OnlineSourceLink], and download ids are
/// `<info-hash>-<file index>`, so the session id alone selects the backend.
class StreamingOrLocalPlayerRepository implements PlayerRepository {
  const StreamingOrLocalPlayerRepository({
    required PlayerRepository streaming,
    required PlayerRepository online,
    required PlayerRepository local,
  }) : _streaming = streaming,
       _online = online,
       _local = local;

  final PlayerRepository _streaming;
  final PlayerRepository _online;
  final PlayerRepository _local;

  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) {
    final backend = _isOnline(magnet) ? _online : _streaming;
    return backend.prepareSource(magnet: magnet, cancelled: cancelled);
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
    if (_isOnline(sessionId)) return _online;
    return int.tryParse(sessionId) != null ? _streaming : _local;
  }

  bool _isOnline(String link) => OnlineSourceLink.tryParse(link) != null;
}
