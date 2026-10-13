import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/data/mock_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_cubit.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_state.dart';

void main() {
  late _GatedRepository repository;
  late UserRateCubit cubit;

  setUp(() {
    repository = _GatedRepository();
    cubit = UserRateCubit(repository: repository, animeId: '1');
  });

  tearDown(() => cubit.close());

  test('signed out there is no list; signing in loads it', () async {
    expect(cubit.state, const UserRateSignedOut());

    await cubit.accountChanged('42');
    expect(cubit.state, const UserRateLoaded(null));

    await cubit.accountChanged(null);
    expect(cubit.state, const UserRateSignedOut());
  });

  test('a list that does not load can be retried', () async {
    repository.failFetch = true;
    await cubit.accountChanged('42');
    expect(cubit.state, const UserRateLoadFailure());

    repository.failFetch = false;
    await cubit.load();
    expect(cubit.state, const UserRateLoaded(null));
  });

  test('a status shows at once and stays once saved', () async {
    await cubit.accountChanged('42');
    repository.gate = Completer();

    cubit.setStatus(UserRateStatus.planned);
    expect(
      cubit.state,
      const UserRateLoaded(
        UserRate(id: '', status: UserRateStatus.planned, episodes: 0),
        saving: true,
      ),
    );

    repository.gate!.complete();
    await pumpEventQueue();
    expect(
      cubit.state,
      const UserRateLoaded(
        UserRate(id: '1', status: UserRateStatus.planned, episodes: 0),
      ),
    );
  });

  test('quick steps add the anime once and send the last count', () async {
    await cubit.accountChanged('42');
    repository.gate = Completer();

    cubit
      ..stepEpisodes(1, total: 12)
      ..stepEpisodes(1, total: 12)
      ..stepEpisodes(1, total: 12);
    expect((cubit.state as UserRateLoaded).rate?.episodes, 3);

    repository.gate!.complete();
    await pumpEventQueue();

    expect(repository.saves.map((save) => save.episodes), [1, 3]);
    expect(repository.saves.map((save) => save.rateId), [null, '1']);
    expect(
      cubit.state,
      const UserRateLoaded(
        UserRate(id: '1', status: UserRateStatus.watching, episodes: 3),
      ),
    );
  });

  test('steps stay within the episodes there are', () async {
    await cubit.accountChanged('42');
    cubit.stepEpisodes(-1, total: 2);
    expect(repository.saves, isEmpty);

    cubit.stepEpisodes(1, total: 2);
    await pumpEventQueue();
    cubit.stepEpisodes(1, total: 2);
    await pumpEventQueue();
    cubit.stepEpisodes(1, total: 2);
    await pumpEventQueue();

    expect((cubit.state as UserRateLoaded).rate?.episodes, 2);
    expect(repository.saves, hasLength(2));
  });

  test('a change Shikimori refuses falls back to what it keeps', () async {
    await cubit.accountChanged('42');
    cubit.setStatus(UserRateStatus.watching);
    await pumpEventQueue();

    repository.failSave = true;
    cubit.setStatus(UserRateStatus.dropped);
    await pumpEventQueue();

    expect(
      cubit.state,
      const UserRateLoaded(
        UserRate(id: '1', status: UserRateStatus.watching, episodes: 0),
        saveFailed: true,
      ),
    );
  });

  test(
    'a score keeps the entry; scoring an unlisted anime completes it',
    () async {
      await cubit.accountChanged('42');

      cubit.setScore(8);
      await pumpEventQueue();
      expect(
        cubit.state,
        const UserRateLoaded(
          UserRate(
            id: '1',
            status: UserRateStatus.completed,
            episodes: 0,
            score: 8,
          ),
        ),
      );

      cubit.setStatus(UserRateStatus.dropped);
      await pumpEventQueue();
      expect((cubit.state as UserRateLoaded).rate?.score, 8);

      cubit.setScore(0);
      await pumpEventQueue();
      expect((cubit.state as UserRateLoaded).rate?.score, 0);
    },
  );

  test('removes the anime from the list', () async {
    await cubit.accountChanged('42');
    cubit.setStatus(UserRateStatus.planned);
    await pumpEventQueue();

    await cubit.remove();

    expect(cubit.state, const UserRateLoaded(null));
    expect(await repository.fetch('1'), isNull);
  });

  test('a change while the entry is removed is not sent', () async {
    await cubit.accountChanged('42');
    cubit.setStatus(UserRateStatus.planned);
    await pumpEventQueue();
    repository
      ..saves.clear()
      ..removeGate = Completer();

    final removal = cubit.remove();
    cubit.setStatus(UserRateStatus.watching);
    repository.removeGate!.complete();
    await removal;

    expect(repository.saves, isEmpty);
    expect(cubit.state, const UserRateLoaded(null));
  });

  test('a save that failed reads the entry again', () async {
    await cubit.accountChanged('42');
    // Shikimori took it, but the answer was lost.
    repository.failSaveAfterSaving = true;

    cubit.setStatus(UserRateStatus.planned);
    await pumpEventQueue();

    expect(
      cubit.state,
      const UserRateLoaded(
        UserRate(id: '1', status: UserRateStatus.planned, episodes: 0),
      ),
    );
  });

  test('a change asked for while the entry is read again goes after it, '
      'to the entry Shikimori keeps', () async {
    await cubit.accountChanged('42');
    repository
      ..failSaveAfterSaving = true
      ..fetchGate = Completer();
    cubit.setStatus(UserRateStatus.watching);
    await pumpEventQueue();
    repository.failSaveAfterSaving = false;

    cubit.setStatus(UserRateStatus.completed);
    expect(repository.saves, hasLength(1), reason: 'held behind the read');
    repository.fetchGate!.complete();
    await pumpEventQueue();

    expect(repository.saves.last.rateId, '1', reason: 'not added twice');
    expect(
      cubit.state,
      const UserRateLoaded(
        UserRate(id: '1', status: UserRateStatus.completed, episodes: 0),
      ),
    );
  });

  test('an entry read elsewhere shows after a failed load', () async {
    repository.failFetch = true;
    await cubit.accountChanged('42');
    expect(cubit.state, const UserRateLoadFailure());
    repository.failFetch = false;

    await repository.fetch('1');
    await pumpEventQueue();

    expect(cubit.state, const UserRateLoaded(null));
  });

  test('a save out when the account changes settles nothing for the next '
      'one', () async {
    await cubit.accountChanged('42');
    cubit.setStatus(UserRateStatus.planned);
    await pumpEventQueue();
    final gate = repository.gate = Completer<void>();

    cubit.setStatus(UserRateStatus.watching);
    await cubit.accountChanged(null);
    repository.gate = null;
    await cubit.accountChanged('7');
    final sent = repository.saves.length;
    cubit.setStatus(UserRateStatus.dropped);
    await pumpEventQueue();

    // Sent at once, not held behind the other account's save.
    expect(repository.saves, hasLength(sent + 1));
    expect((cubit.state as UserRateLoaded).saving, isFalse);
    gate.complete();
  });

  test('a save made elsewhere shows, and the next step builds on it', () async {
    await cubit.accountChanged('42');

    // The player marks episode 5 of an anime not yet in the list.
    await repository.save(
      userId: '42',
      animeId: '1',
      rateId: null,
      status: UserRateStatus.watching,
      episodes: 5,
      score: 0,
    );
    await pumpEventQueue();
    expect(
      cubit.state,
      const UserRateLoaded(
        UserRate(id: '1', status: UserRateStatus.watching, episodes: 5),
      ),
    );

    cubit.stepEpisodes(1, total: 12);
    await pumpEventQueue();
    expect(repository.saves.last, (rateId: '1', episodes: 6));
  });

  test('another anime\'s changes leave the entry alone', () async {
    await cubit.accountChanged('42');

    await repository.save(
      userId: '42',
      animeId: '2',
      rateId: null,
      status: UserRateStatus.watching,
      episodes: 5,
      score: 0,
    );
    await pumpEventQueue();

    expect(cubit.state, const UserRateLoaded(null));
  });
}

class _GatedRepository extends MockUserRateRepository {
  Completer<void>? gate;
  Completer<void>? removeGate;
  Completer<void>? fetchGate;
  bool failFetch = false;
  bool failSave = false;
  bool failSaveAfterSaving = false;
  final saves = <({String? rateId, int episodes})>[];

  @override
  Future<UserRate?> fetch(String animeId) async {
    await fetchGate?.future;
    if (failFetch) throw Exception('offline');
    return super.fetch(animeId);
  }

  @override
  Future<UserRate> save({
    required String userId,
    required String animeId,
    required String? rateId,
    required UserRateStatus status,
    required int episodes,
    required int score,
  }) async {
    saves.add((rateId: rateId, episodes: episodes));
    await gate?.future;
    if (failSave) throw Exception('refused');
    final saved = await super.save(
      userId: userId,
      animeId: animeId,
      rateId: rateId,
      status: status,
      episodes: episodes,
      score: score,
    );
    if (failSaveAfterSaving) throw TimeoutException('no answer');
    return saved;
  }

  @override
  Future<void> remove({required String animeId, required String rateId}) async {
    await removeGate?.future;
    return super.remove(animeId: animeId, rateId: rateId);
  }
}
