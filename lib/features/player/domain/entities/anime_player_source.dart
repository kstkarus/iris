class AnimePlayerSource {
  const AnimePlayerSource({
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AnimePlayerSource &&
        other.animeId == animeId &&
        other.animeTitle == animeTitle &&
        other.sourceTitle == sourceTitle &&
        other.sessionId == sessionId &&
        other.fileIndex == fileIndex &&
        other.fileName == fileName;
  }

  @override
  int get hashCode => Object.hash(
    animeId,
    animeTitle,
    sourceTitle,
    sessionId,
    fileIndex,
    fileName,
  );
}
