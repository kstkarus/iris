import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';

/// A [PlayerRepository] that does nothing unless a test asks for it.
///
/// It records the sessions it starts and disposes. [launches] answers each
/// start; without it, starting playback throws. Extend it and override only
/// what a test needs.
class StubPlayerRepository implements PlayerRepository {
  StubPlayerRepository({this.launches});

  final Stream<PlayerLaunchUpdate> Function(int fileIndex)? launches;
  final startedSessionIds = <String>[];
  final startedFileIndices = <int>[];
  final disposedSessionIds = <String>[];

  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) {
    final launch = launches;
    if (launch == null) throw UnimplementedError();
    startedSessionIds.add(sessionId);
    startedFileIndices.add(fileIndex);
    return launch(fileIndex);
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return const Stream.empty();
  }

  @override
  Future<void> stopPlayback({required String sessionId}) async {}

  @override
  Future<void> disposePlayback({required String sessionId}) async {
    disposedSessionIds.add(sessionId);
  }
}
