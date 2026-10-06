class AnimePlayerSourceArgs {
  const AnimePlayerSourceArgs({
    required this.animeId,
    required this.animeTitle,
    required this.sourceTitle,
    required this.magnet,
    this.autoOpenFileIndex,
  });

  final String animeId;
  final String animeTitle;
  final String sourceTitle;
  final String magnet;

  /// Opens this file right after the torrent is ready ("Continue").
  final int? autoOpenFileIndex;
}
