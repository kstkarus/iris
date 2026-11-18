import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/online_sources/domain/online_episode_files.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';

const downloadedSourcePrefix = 'download-source:';

/// Only completed files of this release, so offline playback never switches
/// dub or torrent behind the user's back.
PreparedPlayerSource? downloadedPlayerSource(
  List<DownloadItem> items,
  String magnet,
) {
  final key = downloadSourceKey(magnet);
  final seen = <int>{};
  final files =
      [
        for (final item in items)
          if (item.status == DownloadStatus.completed &&
              downloadSourceKey(item.magnet) == key &&
              seen.add(item.fileIndex))
            _downloadedFile(item),
      ]..sort((a, b) {
        final left = a.episodeNumber ?? a.number;
        final right = b.episodeNumber ?? b.number;
        if (left != null && right != null && left != right) {
          return left.compareTo(right);
        }
        return a.name.compareTo(b.name);
      });
  if (files.isEmpty) return null;
  return PreparedPlayerSource(
    sessionId: '$downloadedSourcePrefix$key',
    files: List.unmodifiable(files),
  );
}

PlayerVideoFile _downloadedFile(DownloadItem item) {
  final episode = item.isOnline
      ? parseOnlineEpisodeFileName(item.fileName)
      : null;
  return PlayerVideoFile(
    index: item.fileIndex,
    name: item.fileName,
    size: item.totalBytes,
    extension: '',
    episodeNumber: episode?.number,
    title: episode?.title ?? '',
  );
}
