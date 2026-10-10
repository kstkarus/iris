import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/entities/friend/domain/friends_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';

/// Two friends for the mock app: one has every anime in their list, the
/// other none.
class MockFriendsRepository implements FriendsRepository {
  const MockFriendsRepository();

  static const all = [
    Friend(id: '9001', nickname: 'mock_friend', avatarUrl: ''),
    Friend(id: '9002', nickname: 'quiet_friend', avatarUrl: ''),
  ];

  @override
  Future<List<Friend>> friends(String userId) async => all;

  @override
  Future<UserRate?> rateOf({
    required String friendId,
    required String animeId,
  }) async => friendId == all.first.id
      ? const UserRate(
          id: 'mock',
          status: UserRateStatus.watching,
          episodes: 3,
          score: 8,
        )
      : null;
}
