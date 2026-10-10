import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/entities/friend/domain/friends_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';

Friend testFriend(String id) =>
    Friend(id: id, nickname: 'friend_$id', avatarUrl: '');

/// [list] for anyone, and [rates] by friend id.
class FakeFriendsRepository implements FriendsRepository {
  FakeFriendsRepository({this.list = const [], this.rates = const {}});

  List<Friend> list;
  Map<String, UserRate> rates;
  Object? friendsFailure;
  final failingFriends = <String>{};
  final asked = <String>[];
  int friendReads = 0;

  @override
  Future<List<Friend>> friends(String userId) async {
    friendReads++;
    final failure = friendsFailure;
    if (failure != null) throw failure;
    return list;
  }

  @override
  Future<UserRate?> rateOf({
    required String friendId,
    required String animeId,
  }) async {
    asked.add(friendId);
    if (failingFriends.contains(friendId)) throw Exception('offline');
    return rates[friendId];
  }
}
