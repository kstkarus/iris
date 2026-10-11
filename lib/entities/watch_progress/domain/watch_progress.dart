/// How far one file of one torrent has been watched.
///
/// Identity is the torrent (info-hash key) plus the file index, so streaming
/// and a downloaded copy of the same file share one record. The anime fields
/// are filled only when playback was started from that anime's page; they are
/// never guessed from names.
class WatchProgress {
  const WatchProgress({
    required this.torrentKey,
    required this.fileIndex,
    required this.fileName,
    required this.magnet,
    required this.sourceTitle,
    required this.position,
    required this.duration,
    required this.updatedAt,
    this.animeId = '',
    this.animeTitle = '',
  });

  /// Share of the file after which it counts as watched (credits excluded).
  static const finishedFraction = 0.9;

  /// Shorter positions are not worth resuming from.
  static const minResumePosition = Duration(seconds: 10);

  /// Less than this was a look at the file (checking a release, a wrong
  /// file), not watching it.
  static const minContinuePosition = Duration(minutes: 1);

  final String torrentKey;
  final int fileIndex;
  final String fileName;
  final String magnet;
  final String sourceTitle;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;
  final String animeId;
  final String animeTitle;

  String get id =>
      watchProgressId(torrentKey: torrentKey, fileIndex: fileIndex);

  bool get hasAnime => animeId.isNotEmpty;

  /// Anime title when known, otherwise the torrent's own title.
  String get displayTitle => hasAnime ? animeTitle : sourceTitle;

  double get fraction {
    if (duration <= Duration.zero) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  bool get isFinished =>
      duration > Duration.zero && fraction >= finishedFraction;

  /// Worth offering under "Continue watching": watched for a while, or to
  /// the end (then the next file is offered).
  bool get isWorthContinuing => isFinished || position >= minContinuePosition;

  /// Where playback should continue, or null to start from the beginning.
  Duration? get resumePosition {
    if (isFinished || position < minResumePosition) return null;
    return position;
  }

  @override
  bool operator ==(Object other) {
    return other is WatchProgress &&
        other.torrentKey == torrentKey &&
        other.fileIndex == fileIndex &&
        other.fileName == fileName &&
        other.magnet == magnet &&
        other.sourceTitle == sourceTitle &&
        other.position == position &&
        other.duration == duration &&
        other.updatedAt == updatedAt &&
        other.animeId == animeId &&
        other.animeTitle == animeTitle;
  }

  @override
  int get hashCode => Object.hash(
    torrentKey,
    fileIndex,
    fileName,
    magnet,
    sourceTitle,
    position,
    duration,
    updatedAt,
    animeId,
    animeTitle,
  );
}

String watchProgressId({required String torrentKey, required int fileIndex}) =>
    '$torrentKey:$fileIndex';

/// The most recent record of each torrent, most recent first.
List<WatchProgress> latestPerTorrent(Iterable<WatchProgress> progress) {
  final seen = <String>{};
  final sorted = progress.toList()
    ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  return [
    for (final item in sorted)
      if (seen.add(item.torrentKey)) item,
  ];
}

/// Records of one torrent keyed by file index.
Map<int, WatchProgress> progressByFile(
  Iterable<WatchProgress> progress,
  String torrentKey,
) {
  return {
    for (final item in progress)
      if (item.torrentKey == torrentKey) item.fileIndex: item,
  };
}

/// The latest record of each torrent watched from one anime's page.
List<WatchProgress> recentForAnime(
  Iterable<WatchProgress> progress,
  String animeId,
) {
  if (animeId.isEmpty) return const [];
  return latestPerTorrent(progress.where((item) => item.animeId == animeId));
}
