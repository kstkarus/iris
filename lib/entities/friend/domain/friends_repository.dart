import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';

/// Shikimori friends and what they keep in their lists. Both are public.
abstract interface class FriendsRepository {
  /// [userId]'s friends, as Shikimori orders them.
  Future<List<Friend>> friends(String userId);

  /// [friendId]'s entry for [animeId]; null when it is not in the list.
  Future<UserRate?> rateOf({required String friendId, required String animeId});
}
