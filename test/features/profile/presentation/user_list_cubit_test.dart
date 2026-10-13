import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
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
}
