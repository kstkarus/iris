import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/entities/user_rate/data/mock_user_rate_repository.dart';
import 'package:iris/entities/user_rate/data/shared_preferences_episode_sync_repository.dart';
import 'package:iris/entities/user_rate/domain/episode_sync_repository.dart';
import 'package:iris/entities/user_rate/domain/episode_watch_sync.dart';
import 'package:iris/entities/user_rate/domain/mark_episode_watched.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/player/presentation/cubit/episode_mark_cubit.dart';
import 'package:iris/shared/network/network_exceptions.dart';

void main() {
  late SharedPreferences preferences;
  late SharedPreferencesEpisodeSyncRepository storage;
  late _Rates rates;
  late EpisodeWatchSync sync;
  var generation = 0;

  EpisodeWatchSync start({DateTime Function()? now}) => EpisodeWatchSync(
    storage: storage,
    rates: rates,
    sessionGeneration: () => generation,
    now: now,
  );

  Future<void> activate([String userId = '42']) async {
    sync.accountChanged(userId);
    await sync.sync();
  }

  Future<EpisodeMarkResult> watch(
    int episode, {
    String userId = '42',
    String animeId = '1',
  }) => sync(userId: userId, animeId: animeId, episode: episode);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    storage = SharedPreferencesEpisodeSyncRepository(preferences);
    generation = 0;
    rates = _Rates();
    sync = start();
    await activate();
  });

  tearDown(() => sync.close());

  test(
    'offline marks survive restart, deduplicate, and drain in order',
    () async {
      rates.offline = true;
      expect(await watch(2), isA<EpisodeMarkDeferred>());
      await watch(3);
      await watch(2);
      expect(sync.state.pending, 2);
      expect(storage.read().single.episodes, [2, 3]);
      await sync.close();

      // Recreate both the preference reader and worker, as on a cold launch.
      storage = SharedPreferencesEpisodeSyncRepository(preferences);
      rates.offline = false;
      sync = start();
      await activate();
      expect(sync.state.pending, 0);
      expect(rates.writes.map((write) => write.episode), [2, 3]);
      expect(rates.rates['1']?.episodes, 3);
    },
  );

  test('a response lost after accepting a write never counts twice', () async {
    rates.loseResponse = true;
    expect(await watch(5), isA<EpisodeMarkDeferred>());
    expect(rates.rates['1']?.episodes, 5);
    expect(sync.state.pending, 1);

    await sync.retry();
    expect(sync.state.pending, 0);
    expect(rates.writes.length, 1);
    expect(rates.rates['1']?.episodes, 5);
  });

  test(
    'a failed first write freezes its freshly read comparison snapshot',
    () async {
      // The entry was never cached before this first mark.
      await sync.close();
      rates.refused.add('1');
      await rates.seed(4);
      sync = start();
      await activate();
      await watch(5);
      expect(storage.read().single.rate?.episodes, 4);
      await rates.seed(0);
      rates.refused.clear();
      rates.writes.clear();
      await sync.retry();
      expect(sync.state.pending, 0);
      expect(rates.writes, isEmpty);
      expect(rates.rates['1']?.episodes, 0);
    },
  );

  test('a higher website count is acknowledged without writing', () async {
    rates.offline = true;
    await watch(4);
    await rates.seed(8, score: 9);
    rates.offline = false;
    await sync.retry();
    expect(sync.state.pending, 0);
    expect(rates.writes, isEmpty);
    expect(rates.rates['1']?.score, 9);
  });

  test(
    'confirmed reset, removal, replacement and rewatch cancel the whole title',
    () async {
      for (final kind in [
        'reset',
        'removed',
        'replaced',
        'rewatching',
        'rewatches',
      ]) {
        await sync.close();
        await preferences.clear();
        final baseline = await rates.seed(5, rewatches: 1);
        await storage.write([
          EpisodeSyncEntry(
            userId: '42',
            animeId: '1',
            rateKnown: true,
            rate: baseline,
            episodes: [6, 7],
          ),
        ]);
        switch (kind) {
          case 'reset':
            await rates.seed(0, id: baseline.id, rewatches: 1);
          case 'removed':
            await rates.remove(animeId: '1', rateId: baseline.id);
          case 'replaced':
            await rates.seed(5, id: 'replacement', rewatches: 1);
          case 'rewatching':
            await rates.seed(
              5,
              id: baseline.id,
              status: UserRateStatus.rewatching,
              rewatches: 1,
            );
          case 'rewatches':
            await rates.seed(5, id: baseline.id, rewatches: 2);
        }
        rates.writes.clear();
        sync = start();
        await activate();
        expect(sync.state.pending, 0, reason: kind);
        expect(rates.writes, isEmpty, reason: kind);
      }
    },
  );

  test('a fresh score edit survives the partial episode update', () async {
    final baseline = await rates.seed(3, score: 7);
    await sync.close();
    await storage.write([
      EpisodeSyncEntry(
        userId: '42',
        animeId: '1',
        rateKnown: true,
        rate: baseline,
        episodes: [4],
      ),
    ]);
    rates.beforeSave = () => rates.seed(3, id: baseline.id, score: 10);
    sync = start();
    await activate();
    expect(rates.rates['1']?.score, 10);
    expect(rates.rates['1']?.episodes, 4);
    expect(rates.writes.single.score, isNull);
    expect(rates.writes.single.status, isNull);
  });

  test('logout retains work; another account never sends it', () async {
    rates.offline = true;
    await watch(2);
    generation++;
    sync.accountChanged(null);
    rates.offline = false;
    generation++;
    await activate('77');
    expect(sync.state.pending, 0);
    expect(storage.read().single.episodes, [2]);
    expect(rates.writes, isEmpty);

    generation++;
    await activate();
    expect(rates.writes.single.userId, '42');
    expect(sync.state.pending, 0);
  });

  test('session changes during a fetch prevent the following write', () async {
    final reply = Completer<UserRate?>();
    rates.fetchReply = reply;
    final mark = watch(3);
    await rates.fetchStarted.future;
    generation++;
    sync.accountChanged(null);
    reply.complete(null);
    expect(await mark, isA<EpisodeMarkDeferred>());
    expect(rates.writes, isEmpty);
    expect(storage.read().single.episodes, [3]);
  });

  test('caller disposal after saving the intent does not discard it', () async {
    final reply = Completer<UserRate?>();
    rates.fetchReply = reply;
    var callerAlive = true;
    final mark = sync(
      userId: '42',
      animeId: '1',
      episode: 3,
      isCurrent: () => callerAlive,
    );
    await rates.fetchStarted.future;
    callerAlive = false;
    reply.complete(null);
    expect(await mark, isA<EpisodeMarked>());
    expect(rates.rates['1']?.episodes, 3);
    expect(sync.state.pending, 0);
  });

  test(
    'a server refusal is retained and does not block other titles',
    () async {
      rates.refused.add('1');
      expect(await watch(1), isA<EpisodeMarkDeferred>());
      await watch(2);
      expect(rates.writes.length, 1);
      await watch(2, animeId: '2');
      expect(sync.state.pending, 2);
      expect(sync.state.blocked, 2);
      expect(rates.rates['2']?.episodes, 2);
      await sync.close();
      sync = start();
      await activate();
      expect(sync.state.blocked, 2);
      rates.refused.clear();
      await sync.retry();
      expect(sync.state.pending, 0);
      expect(rates.rates['1']?.episodes, 2);
    },
  );

  test('retries back off, pause in background, and stop when empty', () async {
    await sync.close();
    fakeAsync((time) {
      final now = DateTime.utc(2026, 10, 17);
      sync = start(now: () => now.add(time.elapsed));
      sync.accountChanged('42');
      rates.offline = true;
      unawaited(watch(2));
      time.flushMicrotasks();
      expect(rates.fetches, 1);
      time.elapse(const Duration(seconds: 14));
      expect(rates.fetches, 1);
      time.elapse(const Duration(seconds: 1));
      expect(rates.fetches, 2);
      time.elapse(const Duration(seconds: 29));
      expect(rates.fetches, 2);
      time.elapse(const Duration(seconds: 1));
      expect(rates.fetches, 3);
      sync.setForeground(false);
      time.elapse(const Duration(minutes: 10));
      expect(rates.fetches, 3);
      rates.offline = false;
      sync.setForeground(true);
      time.flushMicrotasks();
      expect(sync.state.pending, 0);
      expect(time.nonPeriodicTimerCount, 0);
      unawaited(sync.close());
      time.flushMicrotasks();
    });
  });

  test('a failed durable write is never reported as queued or sent', () async {
    await sync.close();
    final broken = _FailingStorage();
    sync = EpisodeWatchSync(
      storage: broken,
      rates: rates,
      sessionGeneration: () => generation,
    );
    await activate();
    await expectLater(watch(1), throwsStateError);
    expect(sync.state.pending, 0);
    expect(sync.state.storageFailed, isTrue);
    expect(rates.fetches, 0);
    expect(rates.writes, isEmpty);
  });

  test(
    'unknown baselines do not invent conflicts on a first offline viewing',
    () async {
      rates.offline = true;
      await watch(3);
      await rates.seed(0);
      rates.offline = false;
      await sync.retry();
      expect(sync.state.pending, 0);
      expect(rates.rates['1']?.episodes, 3);
    },
  );

  test(
    'last observed server snapshot survives restart for conflict detection',
    () async {
      await rates.seed(4, rewatches: 2);
      // Allow the asynchronous repository change stream and preference write.
      await sync.sync();
      await sync.close();
      expect(storage.read().single.rate?.episodes, 4);
      rates.offline = true;
      sync = start();
      await activate();
      await watch(5);
      await rates.seed(0, rewatches: 2);
      rates.offline = false;
      await sync.retry();
      expect(sync.state.pending, 0);
      expect(rates.writes, isEmpty);
      expect(rates.rates['1']?.episodes, 0);
    },
  );

  test('invalid and stale caller requests never enter the outbox', () async {
    await expectLater(watch(0), throwsArgumentError);
    await expectLater(watch(10000), throwsArgumentError);
    await expectLater(watch(1, userId: '77'), throwsStateError);
    await expectLater(
      sync(userId: '42', animeId: '1', episode: 1, isCurrent: () => false),
      throwsStateError,
    );
    expect(storage.read(), isEmpty);
  });

  test(
    'a retry does not requeue a mark already sent in the background',
    () async {
      rates.offline = true;
      final updates = <EpisodeMarkUpdate>[];
      final subscription = sync.markUpdates.listen(updates.add);
      addTearDown(subscription.cancel);
      expect(await watch(5), isA<EpisodeMarkDeferred>());
      await pumpEventQueue();
      expect(updates.last.result, isA<EpisodeMarkDeferred>());

      rates.offline = false;
      await sync.retry();
      await pumpEventQueue();
      expect(updates.last.result, isA<EpisodeMarked>());
      expect(sync.state.pending, 0);
      final result = await sync.retryMark(
        userId: '42',
        animeId: '1',
        episode: 5,
      );
      expect(result, isA<EpisodeAlreadyMarked>());
      expect(sync.state.pending, 0);
      expect(rates.writes.length, 1);
    },
  );

  test('a reset resolves every queued episode as obsolete', () async {
    final baseline = await rates.seed(3);
    await sync.close();
    await storage.write([
      EpisodeSyncEntry(
        userId: '42',
        animeId: '1',
        rateKnown: true,
        rate: baseline,
        episodes: const [4, 5],
      ),
    ]);
    await rates.seed(0, id: baseline.id);
    sync = start();
    final updates = <EpisodeMarkUpdate>[];
    final subscription = sync.markUpdates.listen(updates.add);
    addTearDown(subscription.cancel);
    await activate();
    await pumpEventQueue();
    expect(updates.map((event) => event.episode), [4, 5]);
    expect(
      updates.every((event) => event.result is EpisodeMarkObsolete),
      isTrue,
    );
    expect(sync.state.pending, 0);
    final result = await sync.retryMark(userId: '42', animeId: '1', episode: 5);
    expect(result, isA<EpisodeMarkObsolete>());
    expect(sync.state.pending, 0);
  });

  test('a reopened player can retry a blocked mark from the outbox', () async {
    rates.refused.add('1');
    expect(await watch(5), isA<EpisodeMarkDeferred>());
    expect(storage.read().single.blocked, isTrue);
    final cubit = EpisodeMarkCubit(
      markEpisode: sync,
      userId: '42',
      animeId: '1',
      sessionGeneration: () => generation,
    );
    addTearDown(cubit.close);
    expect(
      cubit.state,
      isA<EpisodeMarkQueued>()
          .having((state) => state.episode, 'episode', 5)
          .having((state) => state.failed, 'failed', true),
    );
    rates.refused.clear();
    cubit.confirm();
    await pumpEventQueue(times: 100);
    expect(cubit.state, isA<EpisodeMarkDone>());
    expect(sync.state.pending, 0);
    expect(rates.rates['1']?.episodes, 5);
  });
}

class _Rates extends MockUserRateRepository {
  bool offline = false;
  bool loseResponse = false;
  final refused = <String>{};
  int fetches = 0;
  Completer<UserRate?>? fetchReply;
  final fetchStarted = Completer<void>();
  Future<void> Function()? beforeSave;
  final writes =
      <
        ({
          String userId,
          String animeId,
          int episode,
          int? score,
          UserRateStatus? status,
        })
      >[];

  Future<UserRate> seed(
    int episodes, {
    String id = 'rate-1',
    int score = 0,
    UserRateStatus status = UserRateStatus.watching,
    int? rewatches,
  }) => super.save(
    userId: '42',
    animeId: '1',
    rateId: id,
    status: status,
    episodes: episodes,
    score: score,
    rewatches: rewatches,
  );

  @override
  Future<UserRate?> fetch(String animeId) async {
    fetches++;
    if (offline) throw const NetworkRequestException('offline');
    if (fetchReply case final reply?) {
      fetchReply = null;
      if (!fetchStarted.isCompleted) fetchStarted.complete();
      return reply.future;
    }
    return super.fetch(animeId);
  }

  @override
  Future<UserRate> save({
    required String userId,
    required String animeId,
    required String? rateId,
    UserRateStatus? status,
    required int episodes,
    int? score,
    int? rewatches,
  }) async {
    writes.add((
      userId: userId,
      animeId: animeId,
      episode: episodes,
      score: score,
      status: status,
    ));
    if (refused.contains(animeId)) {
      throw const RemoteResponseException('forbidden', statusCode: 403);
    }
    await beforeSave?.call();
    final result = await super.save(
      userId: userId,
      animeId: animeId,
      rateId: rateId,
      status: status,
      episodes: episodes,
      score: score,
      rewatches: rewatches,
    );
    if (loseResponse) {
      loseResponse = false;
      throw const NetworkRequestException('response lost');
    }
    return result;
  }
}

class _FailingStorage implements EpisodeSyncRepository {
  @override
  List<EpisodeSyncEntry> read() => [];

  @override
  Future<void> write(List<EpisodeSyncEntry> entries) async =>
      throw StateError('disk full');
}
