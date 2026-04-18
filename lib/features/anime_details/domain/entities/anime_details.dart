class AnimeDetails {
  const AnimeDetails({
    required this.id,
    required this.name,
    required this.russian,
    required this.description,
    required this.kind,
    required this.score,
    required this.status,
    required this.episodes,
    required this.episodesAired,
    required this.airedOn,
    required this.posterOriginalUrl,
  });

  final String id;
  final String name;
  final String russian;
  final String description;
  final String kind;
  final double score;
  final String status;
  final int episodes;
  final int episodesAired;
  final String airedOn;
  final String posterOriginalUrl;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AnimeDetails &&
        other.id == id &&
        other.name == name &&
        other.russian == russian &&
        other.description == description &&
        other.kind == kind &&
        other.score == score &&
        other.status == status &&
        other.episodes == episodes &&
        other.episodesAired == episodesAired &&
        other.airedOn == airedOn &&
        other.posterOriginalUrl == posterOriginalUrl;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    russian,
    description,
    kind,
    score,
    status,
    episodes,
    episodesAired,
    airedOn,
    posterOriginalUrl,
  );
}
