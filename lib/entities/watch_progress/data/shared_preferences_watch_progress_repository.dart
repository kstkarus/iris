import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/entities/watch_progress/data/watch_progress_model.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress_repository.dart';

class SharedPreferencesWatchProgressRepository
    implements WatchProgressRepository {
  SharedPreferencesWatchProgressRepository(
    this._preferences, {
    this.maxEntries = 500,
  });

  static const _storageKey = 'watch_progress.items';

  final SharedPreferences _preferences;

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

  List<WatchProgress> _items() => _cache ??= _sorted(_read());

  List<WatchProgress> _read() {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return _latestPerFile([
        for (final entry in decoded) ?WatchProgressModel.fromJson(entry),
      ]);
    } on FormatException catch (error, stackTrace) {
      developer.log(
        'Watch progress storage is corrupted; starting with an empty history.',
        name: 'iris.watch_progress.repository',
        error: error,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<void> _write(List<WatchProgress> items) async {
    final sorted = _sorted(items);
    final kept = sorted.length > maxEntries
        ? List<WatchProgress>.unmodifiable(sorted.take(maxEntries))
        : sorted;
    _cache = kept;
    await _preferences.setString(
      _storageKey,
      jsonEncode([for (final item in kept) WatchProgressModel.toJson(item)]),
    );
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
