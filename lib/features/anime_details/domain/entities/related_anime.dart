/// How another title relates to this one, as Shikimori tells it.
enum AnimeRelation {
  prequel,
  sequel,
  parentStory,
  fullStory,
  sideStory,
  alternativeSetting,
  alternativeVersion,
  spinOff,
  summary,
  character,
  other,
}

/// Another anime of the same franchise, with what its page needs to open
/// before its own details load.
class RelatedAnime {
  const RelatedAnime({
    required this.relation,
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
    required this.posterUrl,
  });

  final AnimeRelation relation;
  final String id;
  final String name;
  final String russian;
  final String english;
  final String kind;
  final double score;
  final String status;
  final int episodes;
  final int episodesAired;
  final String airedOn;
  final String posterUrl;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is RelatedAnime &&
        other.relation == relation &&
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
        other.posterUrl == posterUrl;
  }

  @override
  int get hashCode => Object.hash(
    relation,
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
    posterUrl,
  );
}
