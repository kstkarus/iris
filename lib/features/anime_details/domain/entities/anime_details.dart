import 'package:iris/features/anime_details/domain/entities/related_anime.dart';

class AnimeDetails {
  const AnimeDetails({
    required this.id,
    required this.name,
    required this.russian,
    this.english = '',
    required this.description,
    required this.kind,
    required this.score,
    required this.status,
    required this.episodes,
    required this.episodesAired,
    required this.airedOn,
    required this.posterOriginalUrl,
    this.related = const [],
  });

  final String id;
  final String name;
  final String russian;

  /// The licensed English title; empty when there is none.
  final String english;
  final String description;
  final String kind;
  final double score;
  final String status;
  final int episodes;
  final int episodesAired;
  final String airedOn;
  final String posterOriginalUrl;

  /// Other anime of the franchise; adaptations into manga are left out.
  final List<RelatedAnime> related;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AnimeDetails &&
        other.id == id &&
        other.name == name &&
        other.russian == russian &&
        other.english == english &&
        other.description == description &&
        other.kind == kind &&
        other.score == score &&
        other.status == status &&
        other.episodes == episodes &&
        other.episodesAired == episodesAired &&
        other.airedOn == airedOn &&
        other.posterOriginalUrl == posterOriginalUrl &&
        _sameItems(other.related, related);
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    russian,
    english,
    description,
    kind,
    score,
    status,
    episodes,
    episodesAired,
    airedOn,
    posterOriginalUrl,
    Object.hashAll(related),
  );
}

bool _sameItems<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
