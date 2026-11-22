import 'package:iris/entities/anime/domain/anime_titles.dart';

/// How far one file of one torrent has been watched.
///
/// Streaming and a downloaded copy share progress for the same anime.
/// A torrent and file can have separate records when linked to several anime.
/// The anime is never guessed from names.
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
    this.animeRussian = '',
    this.animeEnglish = '',
    this.hiddenFromContinueWatching = false,
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
  final String animeRussian;
  final String animeEnglish;
  final bool hiddenFromContinueWatching;

  String get id =>
      watchProgressId(torrentKey: torrentKey, fileIndex: fileIndex);

  (String, int, String) get recordKey => (torrentKey, fileIndex, animeId);

  bool get hasAnime => animeId.isNotEmpty;

  /// Groups Continue watching entries by anime when known, otherwise by source.
  String get continueWatchingKey => hasAnime ? 'anime:$animeId' : torrentKey;

  /// Whether this record belongs to the same Continue watching row as [target].
  bool matchesContinueWatchingTarget(WatchProgress target) =>
      continueWatchingKey == target.continueWatchingKey;

  WatchProgress copyWith({bool? hiddenFromContinueWatching}) {
    return WatchProgress(
      torrentKey: torrentKey,
      fileIndex: fileIndex,
      fileName: fileName,
      magnet: magnet,
      sourceTitle: sourceTitle,
      position: position,
      duration: duration,
      updatedAt: updatedAt,
      animeId: animeId,
      animeTitle: animeTitle,
      animeRussian: animeRussian,
      animeEnglish: animeEnglish,
      hiddenFromContinueWatching:
          hiddenFromContinueWatching ?? this.hiddenFromContinueWatching,
    );
  }

  /// Anime titles when linked, otherwise the source's own title.
  AnimeTitles get displayTitles => hasAnime
      ? AnimeTitles(
          name: animeTitle,
          russian: animeRussian,
          english: animeEnglish,
        )
      : AnimeTitles(name: sourceTitle);

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
        other.animeTitle == animeTitle &&
        other.animeRussian == animeRussian &&
        other.animeEnglish == animeEnglish &&
        other.hiddenFromContinueWatching == hiddenFromContinueWatching;
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
    animeRussian,
    animeEnglish,
    hiddenFromContinueWatching,
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

/// Newest records keyed by file index. A linked title uses its own records
/// first and can fall back to older history without an anime link.
Map<int, WatchProgress> progressByFile(
  Iterable<WatchProgress> progress,
  String torrentKey, {
  String animeId = '',
}) {
  final files = <int, WatchProgress>{};
  for (final item in progress) {
    if (item.torrentKey != torrentKey ||
        (animeId.isNotEmpty && item.hasAnime && item.animeId != animeId)) {
      continue;
    }
    final existing = files[item.fileIndex];
    if (existing == null ||
        (animeId.isNotEmpty && item.hasAnime != existing.hasAnime
            ? item.hasAnime
            : item.updatedAt.isAfter(existing.updatedAt))) {
      files[item.fileIndex] = item;
    }
  }
  return files;
}

/// The latest record of each torrent watched from one anime's page.
List<WatchProgress> recentForAnime(
  Iterable<WatchProgress> progress,
  String animeId,
) {
  if (animeId.isEmpty) return const [];
  return latestPerTorrent(progress.where((item) => item.animeId == animeId));
}
