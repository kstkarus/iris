import 'package:iris/entities/anime/domain/anime_titles.dart';
import 'package:iris/shared/online/online_source_link.dart';

class DownloadSelectionArgs {
  const DownloadSelectionArgs({
    required this.animeId,
    required this.animeTitles,
    required this.sourceTitle,
    required this.magnet,
    this.posterUrl = '',
  });

  final String animeId;
  final AnimeTitles animeTitles;
  final String sourceTitle;
  final String posterUrl;

  /// A torrent's magnet, or an online release's [OnlineSourceLink].
  final String magnet;

  /// The files to choose from are a release's episodes.
  bool get isOnlineRelease => OnlineSourceLink.tryParse(magnet) != null;
}
