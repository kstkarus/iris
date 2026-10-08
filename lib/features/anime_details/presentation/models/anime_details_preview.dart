import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/features/anime_details/domain/entities/related_anime.dart';

/// What a title page can show before its details load: the catalog
/// already knows all of it, so the page opens with it and only waits for
/// the rest.
class AnimeDetailsPreview {
  const AnimeDetailsPreview({
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

  /// The same fields of loaded details.
  factory AnimeDetailsPreview.fromDetails(AnimeDetails details) =>
      AnimeDetailsPreview(
        id: details.id,
        name: details.name,
        russian: details.russian,
        english: details.english,
        kind: details.kind,
        score: details.score,
        status: details.status,
        episodes: details.episodes,
        episodesAired: details.episodesAired,
        airedOn: details.airedOn,
        posterUrl: details.posterOriginalUrl,
      );

  /// What the franchise list knows of a related title.
  factory AnimeDetailsPreview.fromRelated(RelatedAnime anime) =>
      AnimeDetailsPreview(
        id: anime.id,
        name: anime.name,
        russian: anime.russian,
        english: anime.english,
        kind: anime.kind,
        score: anime.score,
        status: anime.status,
        episodes: anime.episodes,
        episodesAired: anime.episodesAired,
        airedOn: anime.airedOn,
        posterUrl: anime.posterUrl,
      );

  final String id;
  final String name;
  final String russian;

  /// Also searched for releases.
  final String english;
  final String kind;
  final double score;
  final String status;
  final int episodes;
  final int episodesAired;
  final String airedOn;
  final String posterUrl;
}
