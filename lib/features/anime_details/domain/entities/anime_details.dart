import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/anime_details/domain/entities/anime_genre_name.dart';
import 'package:iris/features/anime_details/domain/entities/related_anime.dart';
import 'package:iris/shared/utils/equality.dart';

class AnimeDetails {
  const AnimeDetails({
    required this.anime,
    required this.description,
    this.rating = '',
    this.studios = const [],
    this.genres = const [],
    this.fandubbers = const [],
    this.related = const [],
  });

  /// With the original-size poster and, while airing, the next episode.
  final AnimeSummary anime;
  final String description;

  /// The age rating as Shikimori names it (`pg_13`); empty when unknown.
  final String rating;
  final List<String> studios;

  /// Genres and audiences; the themes are left out.
  final List<AnimeGenreName> genres;

  /// The dub teams.
  final List<String> fandubbers;

  /// Other anime of the franchise; adaptations into manga are left out.
  final List<RelatedAnime> related;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AnimeDetails &&
        other.anime == anime &&
        other.description == description &&
        other.rating == rating &&
        sameList(other.studios, studios) &&
        sameList(other.genres, genres) &&
        sameList(other.fandubbers, fandubbers) &&
        sameList(other.related, related);
  }

  @override
  int get hashCode => Object.hash(
    anime,
    description,
    rating,
    Object.hashAll(studios),
    Object.hashAll(genres),
    Object.hashAll(fandubbers),
    Object.hashAll(related),
  );
}
