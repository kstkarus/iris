import 'package:iris/entities/anime/domain/anime_summary.dart';

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
  const RelatedAnime({required this.relation, required this.anime});

  final AnimeRelation relation;
  final AnimeSummary anime;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RelatedAnime &&
        other.relation == relation &&
        other.anime == anime;
  }

  @override
  int get hashCode => Object.hash(relation, anime);
}
