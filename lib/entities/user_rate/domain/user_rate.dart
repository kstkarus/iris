/// Where an anime stands in the user's Shikimori list.
enum UserRateStatus {
  planned,
  watching,
  rewatching,
  completed,
  onHold,
  dropped,
}

/// The signed-in user's entry for one anime.
class UserRate {
  const UserRate({
    required this.id,
    required this.status,
    required this.episodes,
    this.score = 0,
  });

  static const maxScore = 10;

  final String id;
  final UserRateStatus status;

  /// Episodes watched.
  final int episodes;

  /// 1 to [maxScore]; 0 when not rated.
  final int score;

  @override
  bool operator ==(Object other) =>
      other is UserRate &&
      other.id == id &&
      other.status == status &&
      other.episodes == episodes &&
      other.score == score;

  @override
  int get hashCode => Object.hash(id, status, episodes, score);
}

/// An entry seen or changed: [rate] is null when the anime left the list.
class UserRateChange {
  const UserRateChange(this.animeId, this.rate);

  final String animeId;
  final UserRate? rate;
}
