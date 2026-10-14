import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/profile/domain/repositories/user_list_repository.dart';
import 'package:iris/features/profile/presentation/cubit/user_list_cubit.dart';
import 'package:iris/features/profile/presentation/cubit/user_list_state.dart';

import 'user_list_test_doubles.dart';

void main() {
  late FakeUserListRepository repository;
  late StreamController<UserRateChange> changes;
  late UserListCubit cubit;

  setUp(() {
    repository = FakeUserListRepository({
      UserRateStatus.watching: [listEntry('1'), listEntry('2'), listEntry('3')],
      UserRateStatus.planned: [listEntry('4', status: UserRateStatus.planned)],
    });
    changes = StreamController<UserRateChange>.broadcast();
    cubit = UserListCubit(repository: repository, changes: changes.stream);
  });

  tearDown(() async {
    await cubit.close();
    await changes.close();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  List<String> ids() => [
    for (final entry in cubit.state.entries) entry.anime.id,
  ];

  test('reads what is watched first, then further pages', () async {
    cubit.show('42');
    expect(cubit.state.load, UserListLoad.loading);
    await settle();

    expect(ids(), ['1', '2']);
    expect(cubit.state.hasMore, isTrue);

    await cubit.loadMore();
    expect(ids(), ['1', '2', '3']);
    expect(cubit.state.hasMore, isFalse);

    await cubit.loadMore();
    expect(repository.requests.map((request) => request.page), [1, 2]);
  });

  test('another status starts over, and an older answer is dropped', () async {
    repository.gate = Completer();
    cubit.show('42');
    cubit.select(UserRateStatus.planned);
    repository.gate!.complete();
    await settle();

    expect(cubit.state.status, UserRateStatus.planned);
    expect(ids(), ['4']);
  });

  test('signed out, the list is empty', () async {
    cubit.show('42');
    await settle();

    cubit.show(null);

    expect(cubit.state.userId, isNull);
    expect(cubit.state.entries, isEmpty);
    expect(cubit.state.load, UserListLoad.loaded);
  });

  test('a failed read is tried again', () async {
    repository.failure = Exception('offline');
    cubit.show('42');
    await settle();
    expect(cubit.state.load, UserListLoad.failed);

    repository.failure = null;
    cubit.retry();
    await settle();

    expect(ids(), ['1', '2']);
  });

  test('a failed further page keeps what was read', () async {
    cubit.show('42');
    await settle();
    repository.failure = Exception('offline');

    await cubit.loadMore();

    expect(ids(), ['1', '2']);
    expect(cubit.state.moreFailed, isTrue);
  });

  test('an anime moved into the shown status reads it again', () async {
    cubit.show('42');
    await settle();
    repository.lists[UserRateStatus.watching] = [
      listEntry('9'),
      ...repository.lists[UserRateStatus.watching]!,
    ];

    // Already shown, or moved elsewhere: the rate book covers these.
    changes
      ..add(
        const UserRateChange(
          '1',
          UserRate(id: 'r1', status: UserRateStatus.watching, episodes: 4),
        ),
      )
      ..add(
        const UserRateChange(
          '7',
          UserRate(id: 'r7', status: UserRateStatus.planned, episodes: 0),
        ),
      );
    await settle();
    expect(repository.requests, hasLength(1));

    changes.add(
      const UserRateChange(
        '9',
        UserRate(id: 'r9', status: UserRateStatus.watching, episodes: 1),
      ),
    );
    await settle();
    await settle();

    expect(ids(), ['9', '1']);
  });

  test('an anime that left the status skips nothing further on', () async {
    repository.lists[UserRateStatus.watching] = [
      for (final id in ['1', '2', '3', '4', '5']) listEntry(id),
    ];
    cubit.show('42');
    await settle();
    expect(ids(), ['1', '2']);

    // Finished elsewhere: the server's pages move up by one.
    repository.lists[UserRateStatus.watching]!.removeAt(0);
    changes.add(
      const UserRateChange(
        '1',
        UserRate(id: 'r1', status: UserRateStatus.completed, episodes: 12),
      ),
    );
    await settle();

    await cubit.loadMore();
    await cubit.loadMore();
    expect(ids(), ['1', '2', '3', '4', '5']);
    expect(cubit.state.hasMore, isFalse);
  });

  test('multiple departures do not skip a later page', () async {
    final largeRepository = FakeUserListRepository({
      UserRateStatus.watching: [for (var n = 1; n <= 120; n++) listEntry('$n')],
    }, pageSize: UserListRepository.pageSize);
    final largeChanges = StreamController<UserRateChange>.broadcast();
    final largeCubit = UserListCubit(
      repository: largeRepository,
      changes: largeChanges.stream,
    );
    addTearDown(() async {
      await largeCubit.close();
      await largeChanges.close();
    });

    largeCubit.show('42');
    await settle();
    await largeCubit.loadMore();
    await largeCubit.loadMore();

    for (var n = 1; n <= 31; n++) {
      largeRepository.lists[UserRateStatus.watching]!.removeWhere(
        (entry) => entry.anime.id == '$n',
      );
      largeChanges.add(UserRateChange('$n', null));
    }
    await settle();

    while (largeCubit.state.hasMore) {
      await largeCubit.loadMore();
    }
    expect(
      largeCubit.state.entries.map((entry) => entry.anime.id),
      contains('91'),
    );
  });

  test(
    'a duplicate departure keeps a final in-flight page retryable',
    () async {
      repository.lists[UserRateStatus.watching] = [
        for (final id in ['1', '2', '3', '4']) listEntry(id),
      ];
      cubit.show('42');
      await settle();

      repository.gate = Completer();
      final more = cubit.loadMore();
      repository.lists[UserRateStatus.watching]!.removeAt(0);
      const change = UserRateChange('1', null);
      changes
        ..add(change)
        ..add(change);
      await settle();
      repository.gate!.complete();
      repository.gate = null;
      await more;

      expect(cubit.state.hasMore, isTrue);
      while (cubit.state.hasMore) {
        await cubit.loadMore();
      }
      expect(ids(), contains('3'));
      expect(repository.requests.map((request) => request.page), [1, 2, 1, 2]);
    },
  );

  test('an anime that left while a further page was on its way skips '
      'nothing either', () async {
    repository.lists[UserRateStatus.watching] = [
      for (final id in ['1', '2', '3', '4', '5', '6']) listEntry(id),
    ];
    cubit.show('42');
    await settle();
    repository.gate = Completer();
    final more = cubit.loadMore();

    // Gone on the server before page 2 is read there.
    repository.lists[UserRateStatus.watching]!.removeAt(0);
    changes.add(
      const UserRateChange(
        '1',
        UserRate(id: 'r1', status: UserRateStatus.completed, episodes: 12),
      ),
    );
    await settle();
    repository.gate!.complete();
    repository.gate = null;
    await more;
    expect(ids(), ['1', '2', '4', '5']);

    // Pages 1 and 2 are read again, as either may have moved.
    while (cubit.state.hasMore) {
      await cubit.loadMore();
    }
    expect(ids(), ['1', '2', '4', '5', '3', '6']);
    expect(repository.requests.map((request) => request.page), [1, 2, 1, 2, 3]);
  });

  test('no further page is added while the first is read again', () async {
    cubit.show('42');
    await settle();
    repository.gate = Completer();
    repository.lists[UserRateStatus.watching] = [
      listEntry('9'),
      ...repository.lists[UserRateStatus.watching]!,
    ];
    changes.add(
      const UserRateChange(
        '9',
        UserRate(id: 'r9', status: UserRateStatus.watching, episodes: 1),
      ),
    );
    await settle();

    await cubit.loadMore();
    repository.gate!.complete();
    await settle();

    expect(ids(), ['9', '1']);
    expect(cubit.state.page, 1);
  });
}
