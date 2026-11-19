import 'package:iris/entities/watch_progress/domain/watch_progress.dart';

abstract interface class WatchProgressRepository {
  /// Emits every record, most recently updated first, then again on change.
  Stream<List<WatchProgress>> watchAll();

  Future<WatchProgress?> find({
    required String torrentKey,
    required int fileIndex,
  });

  /// Inserts or replaces the record with the same torrent and file.
  Future<void> save(WatchProgress progress);

  /// Hides the anime (or standalone source) from Continue watching without
  /// deleting saved resume positions; newer playback brings it back.
  Future<void> dismissFromContinueWatching(WatchProgress progress);

  /// Forgets every record of a torrent.
  Future<void> removeTorrent({required String torrentKey});
}
