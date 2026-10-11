import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/entities/watch_progress/data/watch_progress_model.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress_repository.dart';
import 'package:iris/shared/storage/json_list_preference.dart';

class SharedPreferencesWatchProgressRepository
    implements WatchProgressRepository {
  SharedPreferencesWatchProgressRepository(
    SharedPreferences preferences, {
    this.maxEntries = 500,
  }) : _storage = JsonListPreference(
         preferences,
         'watch_progress.items',
         decode: WatchProgressModel.fromJson,
         encode: WatchProgressModel.toJson,
         logName: 'iris.watch_progress.repository',
         corruptedMessage:
             'Watch progress storage is corrupted; starting with an empty '
             'history.',
       );

  final JsonListPreference<WatchProgress> _storage;

  /// Oldest records are dropped beyond this many files.
  final int maxEntries;
  final StreamController<List<WatchProgress>> _changes =
      StreamController<List<WatchProgress>>.broadcast();
  List<WatchProgress>? _cache;

  @override
  Stream<List<WatchProgress>> watchAll() async* {
    yield _items();
    yield* _changes.stream;
  }

  @override
  Future<WatchProgress?> find({
    required String torrentKey,
    required int fileIndex,
  }) async {
    final id = watchProgressId(torrentKey: torrentKey, fileIndex: fileIndex);
    for (final item in _items()) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<void> save(WatchProgress progress) {
    return _write([
      progress,
      for (final item in _items())
        if (item.id != progress.id) item,
    ]);
  }

  @override
  Future<void> removeTorrent({required String torrentKey}) async {
    final items = _items();
    final remaining = items
        .where((item) => item.torrentKey != torrentKey)
        .toList();
    if (remaining.length == items.length) return;
    await _write(remaining);
  }

  Future<void> close() => _changes.close();

  List<WatchProgress> _items() =>
      _cache ??= _sorted(_latestPerFile(_storage.read()));

  Future<void> _write(List<WatchProgress> items) async {
    final sorted = _sorted(items);
    final kept = sorted.length > maxEntries
        ? List<WatchProgress>.unmodifiable(sorted.take(maxEntries))
        : sorted;
    _cache = kept;
    await _storage.write(kept);
    if (!_changes.isClosed) _changes.add(kept);
  }

  /// Records saved under the base32 and the hex key of one torrent meet once
  /// the key is canonical; the newer one stands.
  List<WatchProgress> _latestPerFile(List<WatchProgress> items) {
    final latest = <String, WatchProgress>{};
    for (final item in items) {
      final kept = latest[item.id];
      if (kept == null || item.updatedAt.isAfter(kept.updatedAt)) {
        latest[item.id] = item;
      }
    }
    return latest.values.toList();
  }

  List<WatchProgress> _sorted(List<WatchProgress> items) {
    return List<WatchProgress>.unmodifiable(
      [...items]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    );
  }
}
