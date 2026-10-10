import 'package:iris/entities/user_rate/domain/user_rate.dart';

/// Someone on a user's Shikimori friends list.
class Friend {
  const Friend({
    required this.id,
    required this.nickname,
    required this.avatarUrl,
  });

  final String id;
  final String nickname;

  /// Empty when there is none.
  final String avatarUrl;

  @override
  bool operator ==(Object other) =>
      other is Friend &&
      other.id == id &&
      other.nickname == nickname &&
      other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(id, nickname, avatarUrl);
}

/// A friend's entry for one anime.
class FriendRate {
  const FriendRate({required this.friend, required this.rate});

  final Friend friend;
  final UserRate rate;

  @override
  bool operator ==(Object other) =>
      other is FriendRate && other.friend == friend && other.rate == rate;

  @override
  int get hashCode => Object.hash(friend, rate);
}
