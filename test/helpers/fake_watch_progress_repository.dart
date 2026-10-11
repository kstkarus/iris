import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress_repository.dart';

/// Watch history that always lists [items] and ignores writes.
class FixedWatchProgressRepository implements WatchProgressRepository {
  const FixedWatchProgressRepository([this.items = const []]);

  final List<WatchProgress> items;

  @override
  Stream<List<WatchProgress>> watchAll() => Stream.value(items);

  @override
  Future<WatchProgress?> find({
    required String torrentKey,
    required int fileIndex,
  }) async => null;

  @override
  Future<void> save(WatchProgress progress) async {}

  @override
  Future<void> removeTorrent({required String torrentKey}) async {}
}
