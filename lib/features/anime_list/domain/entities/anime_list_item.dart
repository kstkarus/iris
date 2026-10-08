class AnimeListItem {
  const AnimeListItem({
    required this.id,
    required this.name,
    required this.russian,
    this.english = '',
    required this.kind,
    required this.score,
    required this.status,
    required this.episodes,
    required this.episodesAired,
    required this.airedOn,
    required this.posterMainUrl,
  });

  final String id;
  final String name;
  final String russian;

  /// The licensed English title; empty when there is none.
  final String english;
  final String kind;
  final double score;
  final String status;
  final int episodes;
  final int episodesAired;
  final String airedOn;
  final String posterMainUrl;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AnimeListItem &&
        other.id == id &&
        other.name == name &&
        other.russian == russian &&
        other.english == english &&
        other.kind == kind &&
        other.score == score &&
        other.status == status &&
        other.episodes == episodes &&
        other.episodesAired == episodesAired &&
        other.airedOn == airedOn &&
        other.posterMainUrl == posterMainUrl;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    russian,
    english,
    kind,
    score,
    status,
    episodes,
    episodesAired,
    airedOn,
    posterMainUrl,
  );
}
