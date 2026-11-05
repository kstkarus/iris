import 'dart:async';
import 'dart:developer' as developer;

import 'package:iris/entities/user_rate/domain/episode_sync_repository.dart';
import 'package:iris/entities/user_rate/domain/mark_episode_watched.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/domain/user_rate_repository.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/utils/serial_queue.dart';

class EpisodeSyncState {
  const EpisodeSyncState({
    this.pending = 0,
    this.blocked = 0,
    this.syncing = false,
    this.storageFailed = false,
  });

  final int pending;
  final int blocked;
  final bool syncing;
  final bool storageFailed;

  @override
  bool operator ==(Object other) =>
      other is EpisodeSyncState &&
      pending == other.pending &&
      blocked == other.blocked &&
      syncing == other.syncing &&
      storageFailed == other.storageFailed;

  @override
  int get hashCode => Object.hash(pending, blocked, syncing, storageFailed);
}

/// A durable outbox for watched episodes, scoped to the signed-in account.
/// Writes absolute counts, so a lost response cannot count an episode twice.
class EpisodeWatchSync implements EpisodeMarker, EpisodeMarkSync {
  EpisodeWatchSync({
    required EpisodeSyncRepository storage,
    required UserRateRepository rates,
    required int Function() sessionGeneration,
    DateTime Function()? now,
  }) : _storage = storage,
       _rates = rates,
       _mark = MarkEpisodeWatched(rates),
       _sessionGeneration = sessionGeneration,
       _now = now ?? DateTime.now,
       _entries = storage.read();

  final EpisodeSyncRepository _storage;
  final UserRateRepository _rates;
  final MarkEpisodeWatched _mark;
  final int Function() _sessionGeneration;
  final DateTime Function() _now;
  final _storageQueue = SerialQueue();
  final _networkQueue = SerialQueue();
  final _changes = StreamController<EpisodeSyncState>.broadcast();
  final _markUpdates = StreamController<EpisodeMarkUpdate>.broadcast();
  final _retryAt = <String, DateTime>{};
  final _attempts = <String, int>{};
  List<EpisodeSyncEntry> _entries;
  StreamSubscription<UserRateChange>? _ratesSubscription;
  Timer? _timer;
  Future<void>? _draining;
  Future<void>? _writing;
  String? _userId;
  int _generation = -1;
  bool _foreground = true;
  bool _closed = false;
  bool _sending = false;
  bool _storageFailed = false;
  EpisodeSyncState _state = const EpisodeSyncState();

  EpisodeSyncState get state => _state;
  Stream<EpisodeSyncState> get changes => _changes.stream;
  @override
  Stream<EpisodeMarkUpdate> get markUpdates => _markUpdates.stream;

  @override
  List<EpisodeMarkUpdate> pendingMarks({
    required String userId,
    required String animeId,
  }) {
    final entry = _find(userId, animeId);
    if (entry == null) return const [];
    return [
      for (final episode in entry.episodes)
        EpisodeMarkUpdate(
          userId: userId,
          animeId: animeId,
          episode: episode,
          generation: _generation,
          result: const EpisodeMarkDeferred(),
          blocked: entry.blocked,
        ),
    ];
  }

  void accountChanged(String? userId) {
    if (_closed || (userId == _userId && _generation == _sessionGeneration())) {
      return;
    }
    _ratesSubscription?.cancel();
    _userId = userId;
    _generation = _sessionGeneration();
    _retryAt.clear();
    _attempts.clear();
    if (userId != null) {
      final generation = _generation;
      _ratesSubscription = _rates.changes.listen((change) {
        unawaited(_remember(userId, generation, change));
      });
    }
    _publish();
    unawaited(sync());
  }

  void setForeground(bool foreground) {
    if (_closed) return;
    _foreground = foreground;
    _timer?.cancel();
    if (foreground) {
      _retryAt.clear();
      unawaited(sync());
    }
  }

  @override
  Future<EpisodeMarkResult> call({
    required String userId,
    required String animeId,
    required int episode,
    bool Function()? isCurrent,
  }) async {
    if (animeId.isEmpty || episode < 1 || episode > 9999) {
      throw ArgumentError('Invalid watched episode');
    }
    if (!_current(userId, _generation) || (isCurrent != null && !isCurrent())) {
      throw StateError('Account session changed');
    }
    final generation = _generation;
    await _update(
      userId,
      animeId,
      (entry) => entry.episodes.contains(episode)
          ? entry
          : entry.withEpisodes([
              ...entry.episodes,
              episode,
            ], blocked: entry.blocked),
    );
    try {
      return await _networkQueue.run(() async {
        final entry = _find(userId, animeId);
        if (entry == null || entry.episodes.isEmpty) {
          return const EpisodeAlreadyMarked();
        }
        if (!_canSend(userId, generation) ||
            entry.blocked ||
            (_retryAt[animeId]?.isAfter(_now()) ?? false)) {
          return const EpisodeMarkDeferred();
        }
        final first = entry.episodes.first;
        final result = await _send(entry, generation);
        return first == episode ? result : const EpisodeMarkDeferred();
      });
    } finally {
      _schedule();
    }
  }

  @override
  Future<bool> undo({
    required String userId,
    required String animeId,
    required EpisodeMarked mark,
    bool Function()? isCurrent,
  }) {
    final generation = _generation;
    return _networkQueue.run(
      () => _mark.undo(
        userId: userId,
        animeId: animeId,
        mark: mark,
        isCurrent: () =>
            _current(userId, generation) && (isCurrent == null || isCurrent()),
      ),
    );
  }

  @override
  Future<EpisodeMarkResult> retryMark({
    required String userId,
    required String animeId,
    required int episode,
    bool Function()? isCurrent,
  }) async {
    final generation = _generation;
    if (!_current(userId, generation) || (isCurrent != null && !isCurrent())) {
      throw StateError('Account session changed');
    }
    await _mutate(
      (entries) => [
        for (final entry in entries)
          if (entry.userId == userId && entry.animeId == animeId)
            entry.withEpisodes(entry.episodes)
          else
            entry,
      ],
    );
    _retryAt.remove(animeId);
    _attempts.remove(animeId);
    try {
      return await _networkQueue.run(() async {
        if (!_current(userId, generation) ||
            (isCurrent != null && !isCurrent())) {
          throw StateError('Account session changed');
        }
        final entry = _find(userId, animeId);
        if (entry == null || !entry.episodes.contains(episode)) {
          final current = entry?.rate;
          return current != null && current.episodes >= episode
              ? EpisodeAlreadyMarked(current: current)
              : EpisodeMarkObsolete(current);
        }
        if (!_canSend(userId, generation) ||
            entry.blocked ||
            (_retryAt[animeId]?.isAfter(_now()) ?? false)) {
          return const EpisodeMarkDeferred();
        }
        final result = await _send(entry, generation);
        return entry.episodes.first == episode
            ? result
            : const EpisodeMarkDeferred();
      });
    } finally {
      _schedule();
    }
  }

  /// Explicit retry also releases requests refused by the server (e.g. 403).
  Future<void> retry() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _mutate(
        (entries) => [
          for (final entry in entries)
            if (entry.userId == userId && entry.blocked)
              entry.withEpisodes(entry.episodes)
            else
              entry,
        ],
      );
      _retryAt.clear();
      _attempts.clear();
      await sync();
    } on Object catch (error, stack) {
      _log(error, stack);
    }
  }

  Future<void> sync() {
    if (_draining != null) return _draining!;
    final userId = _userId;
    final generation = _generation;
    if (userId == null || !_canSend(userId, generation)) return Future.value();
    _timer?.cancel();
    return _draining = _networkQueue
        .run(() async {
          while (_canSend(userId, generation)) {
            final ready = _entries.where(
              (entry) =>
                  entry.userId == userId &&
                  entry.episodes.isNotEmpty &&
                  !entry.blocked &&
                  !(_retryAt[entry.animeId]?.isAfter(_now()) ?? false),
            );
            if (ready.isEmpty) break;
            await _send(ready.first, generation);
          }
        })
        .whenComplete(() {
          _draining = null;
          _publish();
          _schedule();
        });
  }

  Future<EpisodeMarkResult> _send(
    EpisodeSyncEntry entry,
    int generation,
  ) async {
    _sending = true;
    _publish();
    try {
      final result = await _mark(
        userId: entry.userId,
        animeId: entry.animeId,
        episode: entry.episodes.first,
        baselineKnown: entry.rateKnown,
        baseline: entry.rate,
        isCurrent: () => _current(entry.userId, generation),
        beforeSave: entry.rateKnown
            ? null
            : (current) => _update(
                entry.userId,
                entry.animeId,
                (latest) => latest.observed(current),
              ),
      );
      if (!_current(entry.userId, generation)) {
        return const EpisodeMarkDeferred();
      }
      final current = switch (result) {
        EpisodeMarked(:final saved) => saved,
        EpisodeAlreadyMarked(:final current) ||
        EpisodeMarkObsolete(:final current) => current,
        EpisodeMarkDeferred() => throw StateError('Unexpected deferred mark'),
      };
      var obsoleteEpisodes = <int>[];
      await _update(entry.userId, entry.animeId, (latest) {
        if (result is EpisodeMarkObsolete) obsoleteEpisodes = latest.episodes;
        return latest.observed(
          current,
          remaining: result is EpisodeMarkObsolete
              ? []
              : latest.episodes
                    .where((episode) => episode != entry.episodes.first)
                    .toList(),
        );
      });
      _retryAt.remove(entry.animeId);
      _attempts.remove(entry.animeId);
      if (!_current(entry.userId, generation)) {
        return const EpisodeMarkDeferred();
      }
      for (final episode
          in obsoleteEpisodes.isEmpty
              ? [entry.episodes.first]
              : obsoleteEpisodes) {
        _markUpdates.add(
          EpisodeMarkUpdate(
            userId: entry.userId,
            animeId: entry.animeId,
            episode: episode,
            generation: generation,
            result: result,
          ),
        );
      }
      return result;
    } on Object catch (error, stack) {
      _log(error, stack);
      if (_current(entry.userId, generation)) {
        final attempt = (_attempts[entry.animeId] ?? 0) + 1;
        _attempts[entry.animeId] = attempt;
        final seconds = switch (attempt) {
          1 => 15,
          2 => 30,
          3 => 60,
          _ => 300,
        };
        _retryAt[entry.animeId] = _now().add(Duration(seconds: seconds));
        if (error is ResourceNotFoundException ||
            error is RemoteResponseException &&
                const [400, 403, 404, 422].contains(error.statusCode)) {
          try {
            await _update(
              entry.userId,
              entry.animeId,
              (latest) => latest.withEpisodes(latest.episodes, blocked: true),
            );
          } on Object catch (error, stack) {
            _log(error, stack);
          }
        }
      }
      final deferred = const EpisodeMarkDeferred();
      if (_current(entry.userId, generation)) {
        final latest = _find(entry.userId, entry.animeId);
        final blocked = latest?.blocked ?? false;
        for (final episode
            in blocked ? latest!.episodes : [entry.episodes.first]) {
          _markUpdates.add(
            EpisodeMarkUpdate(
              userId: entry.userId,
              animeId: entry.animeId,
              episode: episode,
              generation: generation,
              result: deferred,
              blocked: blocked,
              failed: error is! NetworkRequestException,
            ),
          );
        }
      }
      return deferred;
    } finally {
      _sending = false;
      _publish();
    }
  }

  Future<void> _remember(
    String userId,
    int generation,
    UserRateChange change,
  ) async {
    try {
      await _storageQueue.run(() async {
        if (!_current(userId, generation)) return;
        final entry = _find(userId, change.animeId);
        // Freeze the comparison snapshot until all older marks are resolved.
        if (entry?.episodes.isNotEmpty ?? false) return;
        await _write([
          for (final old in _entries)
            if (old.userId != userId || old.animeId != change.animeId) old,
          (entry ?? EpisodeSyncEntry(userId: userId, animeId: change.animeId))
              .observed(change.rate),
        ]);
      });
    } on Object catch (error, stack) {
      _log(error, stack);
    }
  }

  EpisodeSyncEntry? _find(String userId, String animeId) {
    for (final entry in _entries) {
      if (entry.userId == userId && entry.animeId == animeId) return entry;
    }
    return null;
  }

  Future<void> _update(
    String userId,
    String animeId,
    EpisodeSyncEntry Function(EpisodeSyncEntry entry) update,
  ) => _mutate(
    (entries) => [
      for (final entry in entries)
        if (entry.userId != userId || entry.animeId != animeId) entry,
      update(
        _find(userId, animeId) ??
            EpisodeSyncEntry(userId: userId, animeId: animeId),
      ),
    ],
  );

  Future<void> _mutate(
    List<EpisodeSyncEntry> Function(List<EpisodeSyncEntry>) update,
  ) => _storageQueue.run(() => _write(update(_entries)));

  Future<void> _write(List<EpisodeSyncEntry> entries) async {
    if (_closed) throw StateError('Episode synchronization is closed');
    // Cache eviction never removes unsent work, including another account's.
    var cached = entries.where((entry) => entry.episodes.isEmpty).length;
    final kept = [
      for (final entry in entries)
        if (entry.episodes.isNotEmpty || cached-- <= 500) entry,
    ];
    try {
      await (_writing = _storage.write(kept));
      _entries = kept;
      _storageFailed = false;
    } on Object {
      _storageFailed = true;
      rethrow;
    } finally {
      _writing = null;
      _publish();
    }
  }

  bool _current(String userId, int generation) =>
      !_closed &&
      userId == _userId &&
      generation == _generation &&
      generation == _sessionGeneration();
  bool _canSend(String userId, int generation) =>
      _foreground && _current(userId, generation);

  void _schedule() {
    _timer?.cancel();
    final userId = _userId;
    if (userId == null || !_canSend(userId, _generation) || _draining != null) {
      return;
    }
    DateTime? next;
    for (final entry in _entries) {
      if (entry.userId != userId || entry.episodes.isEmpty || entry.blocked) {
        continue;
      }
      final due = _retryAt[entry.animeId] ?? _now();
      if (next == null || due.isBefore(next)) next = due;
    }
    if (next == null) return;
    final delay = next.difference(_now());
    _timer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(sync()),
    );
  }

  void _publish() {
    if (_closed) return;
    final mine = _entries.where((entry) => entry.userId == _userId);
    final next = EpisodeSyncState(
      pending: mine.fold(0, (sum, entry) => sum + entry.episodes.length),
      blocked: mine
          .where((entry) => entry.blocked)
          .fold(0, (sum, entry) => sum + entry.episodes.length),
      syncing: _sending,
      storageFailed: _storageFailed,
    );
    if (next == _state) return;
    _state = next;
    _changes.add(next);
  }

  void _log(Object error, StackTrace stack) => developer.log(
    'Episode synchronization deferred.',
    name: 'EpisodeSync',
    error: error,
    stackTrace: stack,
  );

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    await _ratesSubscription?.cancel();
    await _writing;
    // A paused UI subscriber must not hold disposal open.
    unawaited(_changes.close());
    unawaited(_markUpdates.close());
  }
}
