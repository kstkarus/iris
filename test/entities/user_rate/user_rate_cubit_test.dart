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

  test('removes the anime from the list', () async {
    await cubit.accountChanged('42');
    cubit.setStatus(UserRateStatus.planned);
    await pumpEventQueue();

    await cubit.remove();

    expect(cubit.state, const UserRateLoaded(null));
    expect(await repository.fetch('1'), isNull);
  });
}

class _GatedRepository extends MockUserRateRepository {
  Completer<void>? gate;
  bool failFetch = false;
  bool failSave = false;
  final saves = <({String? rateId, int episodes})>[];

  @override
  Future<UserRate?> fetch(String animeId) async {
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
  }) async {
    saves.add((rateId: rateId, episodes: episodes));
    await gate?.future;
    if (failSave) throw Exception('refused');
    return super.save(
      userId: userId,
      animeId: animeId,
      rateId: rateId,
      status: status,
      episodes: episodes,
    );
  }
}
