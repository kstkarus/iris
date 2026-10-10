/// The Shikimori account the app is signed in as.
class ShikimoriAccount {
  const ShikimoriAccount({
    required this.id,
    required this.nickname,
    required this.avatarUrl,
  });

  final String id;
  final String nickname;

  /// Empty when Shikimori gives none.
  final String avatarUrl;

  @override
  bool operator ==(Object other) =>
      other is ShikimoriAccount &&
      other.id == id &&
      other.nickname == nickname &&
      other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(id, nickname, avatarUrl);
}
