import 'package:iris/features/anime_details/domain/entities/anime_details.dart';

/// What a title page can show before its details load: the catalog
/// already knows all of it, so the page opens with it and only waits for
/// the rest.
class AnimeDetailsPreview {
  const AnimeDetailsPreview({
    required this.id,
    required this.name,
    required this.russian,
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
        kind: details.kind,
        score: details.score,
        status: details.status,
        episodes: details.episodes,
        episodesAired: details.episodesAired,
        airedOn: details.airedOn,
        posterUrl: details.posterOriginalUrl,
      );

  final String id;
  final String name;
  final String russian;
  final String kind;
  final double score;
  final String status;
  final int episodes;
  final int episodesAired;
  final String airedOn;
  final String posterUrl;
}
