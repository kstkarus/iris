import 'package:iris/entities/anime/domain/anime_titles.dart';

class AnimeWatchSourcesArgs {
  const AnimeWatchSourcesArgs({
    required this.animeId,
    required this.animeTitles,
    required this.searchTitles,
    this.posterUrl = '',
  });

  /// The names releases may use, without repeats: the main (romaji) one
  /// and the English one.
  factory AnimeWatchSourcesArgs.forAnime({
    required String animeId,
    required AnimeTitles animeTitles,
    String posterUrl = '',
  }) {
    final seen = <String>{};
    return AnimeWatchSourcesArgs(
      animeId: animeId,
      animeTitles: animeTitles,
      searchTitles: [
        for (final title in [animeTitles.name, animeTitles.english])
          if (title.trim().isNotEmpty && seen.add(title.trim().toLowerCase()))
            title.trim(),
      ],
      posterUrl: posterUrl,
    );
  }

  final String animeId;

  final AnimeTitles animeTitles;
  final String posterUrl;

  /// What releases are searched by.
  final List<String> searchTitles;
}
