import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/features/anime_details/domain/entities/anime_genre_name.dart';

/// What a title page can show before its details load: the list it was
/// opened from already knows the summary, so the page opens with it and
/// only waits for the rest.
class AnimeDetailsPreview {
  /// What a list knows of a title.
  const AnimeDetailsPreview.fromSummary(this.anime)
    : rating = '',
      studios = const [],
      genres = const [];

  /// The same fields of loaded details.
  AnimeDetailsPreview.fromDetails(AnimeDetails details)
    : anime = details.anime,
      rating = details.rating,
      studios = details.studios,
      genres = details.genres;

  /// Its English title is also searched for releases.
  final AnimeSummary anime;

  /// The facts only the details carry.
  final String rating;
  final List<String> studios;
  final List<AnimeGenreName> genres;
}
