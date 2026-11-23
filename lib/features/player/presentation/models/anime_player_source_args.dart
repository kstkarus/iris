import 'package:iris/entities/anime/domain/anime_titles.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress.dart';

class AnimePlayerSourceArgs {
  const AnimePlayerSourceArgs({
    required this.animeId,
    required this.animeTitles,
    required this.sourceTitle,
    required this.magnet,
    this.posterUrl = '',
    this.autoOpenFileIndex,
    this.preferDownloads = false,
    this.initialDownloadMode = false,
  });

  /// Back to the torrent of [progress]; a finished file opens the picker,
  /// which offers the next one.
  AnimePlayerSourceArgs.resume(WatchProgress progress)
    : this(
        animeId: progress.animeId,
        animeTitles: progress.displayTitles,
        sourceTitle: progress.sourceTitle,
        magnet: progress.magnet,
        autoOpenFileIndex: progress.isFinished ? null : progress.fileIndex,
        preferDownloads: true,
      );

  final String animeId;
  final AnimeTitles animeTitles;
  final String sourceTitle;
  final String magnet;
  final String posterUrl;

  /// Opens this file right after the torrent is ready ("Continue").
  final int? autoOpenFileIndex;

  /// Lets an explicit history jump open a completed file without metadata.
  final bool preferDownloads;

  final bool initialDownloadMode;
}
