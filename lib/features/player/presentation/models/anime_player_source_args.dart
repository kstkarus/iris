import 'package:iris/entities/watch_progress/domain/watch_progress.dart';

class AnimePlayerSourceArgs {
  const AnimePlayerSourceArgs({
    required this.animeId,
    required this.animeTitle,
    required this.sourceTitle,
    required this.magnet,
    this.autoOpenFileIndex,
    this.preferDownloads = false,
  });

  /// Back to the torrent of [progress]; a finished file opens the picker,
  /// which offers the next one.
  AnimePlayerSourceArgs.resume(WatchProgress progress)
    : this(
        animeId: progress.animeId,
        animeTitle: progress.displayTitle,
        sourceTitle: progress.sourceTitle,
        magnet: progress.magnet,
        autoOpenFileIndex: progress.isFinished ? null : progress.fileIndex,
        preferDownloads: true,
      );

  final String animeId;
  final String animeTitle;
  final String sourceTitle;
  final String magnet;

  /// Opens this file right after the torrent is ready ("Continue").
  final int? autoOpenFileIndex;

  /// Resume this release from its completed downloads when available.
  final bool preferDownloads;
}
