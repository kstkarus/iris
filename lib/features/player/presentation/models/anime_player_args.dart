class AnimePlayerArgs {
  const AnimePlayerArgs({
    required this.animeId,
    required this.animeTitle,
    required this.sourceTitle,
    required this.sessionId,
    required this.fileIndex,
    required this.fileName,
  });

  final String animeId;
  final String animeTitle;
  final String sourceTitle;
  final String sessionId;
  final int fileIndex;
  final String fileName;
}
