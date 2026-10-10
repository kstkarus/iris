import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/anime_details/presentation/cubit/friend_rates_cubit.dart';

import '../../../../entities/friend/friend_test_doubles.dart';

void main() {
  const watching = UserRate(
    id: 'a',
    status: UserRateStatus.watching,
    episodes: 3,
  );
  const dropped = UserRate(
    id: 'b',
    status: UserRateStatus.dropped,
    episodes: 1,
  );

  test('lists the friends who have the anime, in their order', () async {
    final repository = FakeFriendsRepository(
      list: [testFriend('1'), testFriend('2'), testFriend('3')],
      rates: {'3': watching, '1': dropped},
    );
    final cubit = FriendRatesCubit(animeId: '10', repository: repository);

    await cubit.show('42');

    expect(cubit.state, [
      FriendRate(friend: testFriend('1'), rate: dropped),
      FriendRate(friend: testFriend('3'), rate: watching),
    ]);
    await cubit.close();
  });

  test('asks about the first friends only', () async {
    final repository = FakeFriendsRepository(
      list: [for (var i = 0; i < 40; i++) testFriend('$i')],
    );
    final cubit = FriendRatesCubit(animeId: '10', repository: repository);

    await cubit.show('42');

    expect(repository.asked, hasLength(FriendRatesCubit.maxFriends));
    await cubit.close();
  });

  test('a friend not answering leaves the others', () async {
    final repository = FakeFriendsRepository(
      list: [testFriend('1'), testFriend('2')],
      rates: {'2': watching},
    )..failingFriends.add('1');
    final cubit = FriendRatesCubit(animeId: '10', repository: repository);

    await cubit.show('42');

    expect(cubit.state.single.friend, testFriend('2'));
    await cubit.close();
  });

  test('friends that do not load, or signing out, show nothing', () async {
    final repository = FakeFriendsRepository(
      list: [testFriend('1')],
      rates: {'1': watching},
    );
    final cubit = FriendRatesCubit(animeId: '10', repository: repository);
    await cubit.show('42');
    expect(cubit.state, isNotEmpty);

    await cubit.show(null);
    expect(cubit.state, isEmpty);

    repository.friendsFailure = Exception('offline');
    await cubit.show('42');
    expect(cubit.state, isEmpty);
    await cubit.close();
  });

  test('a newer account stops the older read', () async {
    final repository = FakeFriendsRepository(
      list: [testFriend('1'), testFriend('2')],
      rates: {'1': watching, '2': watching},
    );
    final cubit = FriendRatesCubit(animeId: '10', repository: repository);

    final first = cubit.show('42');
    await cubit.show(null);
    await first;

    expect(cubit.state, isEmpty);
    expect(repository.asked.length, lessThan(2));
    await cubit.close();
  });
}
