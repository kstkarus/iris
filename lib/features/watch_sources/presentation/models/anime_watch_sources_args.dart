class AnimeWatchSourcesArgs {
  const AnimeWatchSourcesArgs({
    required this.animeId,
    required this.animeTitle,
    required this.searchTitles,
    this.posterUrl = '',
  });

  /// The names releases may use, without repeats: the main (romaji) one
  /// and the English one.
  factory AnimeWatchSourcesArgs.forAnime({
    required String animeId,
    required String name,
    String english = '',
    String posterUrl = '',
  }) {
    final seen = <String>{};
    return AnimeWatchSourcesArgs(
      animeId: animeId,
      animeTitle: name,
      searchTitles: [
        for (final title in [name, english])
          if (title.trim().isNotEmpty && seen.add(title.trim().toLowerCase()))
            title.trim(),
      ],
      posterUrl: posterUrl,
    );
  }

  final String animeId;

  /// How the page names the anime.
  final String animeTitle;
  final String posterUrl;

  /// What releases are searched by.
  final List<String> searchTitles;
}
