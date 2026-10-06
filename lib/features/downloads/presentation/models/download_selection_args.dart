class DownloadSelectionArgs {
  const DownloadSelectionArgs({
    required this.animeId,
    required this.animeTitle,
    required this.sourceTitle,
    required this.magnet,
  });

  final String animeId;
  final String animeTitle;
  final String sourceTitle;
  final String magnet;
}
