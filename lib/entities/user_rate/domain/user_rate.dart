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
  });

  final String id;
  final UserRateStatus status;

  /// Episodes watched.
  final int episodes;

  UserRate copyWith({UserRateStatus? status, int? episodes}) => UserRate(
    id: id,
    status: status ?? this.status,
    episodes: episodes ?? this.episodes,
  );

  @override
  bool operator ==(Object other) =>
      other is UserRate &&
      other.id == id &&
      other.status == status &&
      other.episodes == episodes;

  @override
  int get hashCode => Object.hash(id, status, episodes);
}
