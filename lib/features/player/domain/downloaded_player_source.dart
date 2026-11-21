import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/online_sources/domain/online_episode_files.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';

const downloadedSourcePrefix = 'download-source:';

String downloadedSourceSessionId(
  String animeId,
  String magnet, {
  int? sharedFileIndex,
}) {
  final scope = Uri.encodeComponent(animeId);
  final shared = sharedFileIndex == null ? '' : '/$sharedFileIndex';
  return '$downloadedSourcePrefix$scope$shared:${downloadSourceKey(magnet)}';
}

/// Completed files for this title, plus an explicitly resumed torrent file
/// if its local copy belongs to a different title.
PreparedPlayerSource? downloadedPlayerSource(
  List<DownloadItem> items,
  String magnet, {
  required String animeId,
  int? preferredFileIndex,
}) {
  final sourceKey = downloadSourceKey(magnet);
  final completed = items.where(
    (item) =>
        item.status == DownloadStatus.completed &&
        downloadSourceKey(item.magnet) == sourceKey,
  );
  final seen = <int>{};
  final files = [
    for (final item in completed)
      if (item.animeId == animeId && seen.add(item.fileIndex))
        _downloadedFile(item),
  ];
  int? sharedFileIndex;
  if (preferredFileIndex != null && !seen.contains(preferredFileIndex)) {
    final preferred = completed
        .where((item) => !item.isOnline && item.fileIndex == preferredFileIndex)
        .firstOrNull;
    if (preferred == null) return null;
    files.add(_downloadedFile(preferred));
    sharedFileIndex = preferredFileIndex;
  }
  if (files.isEmpty) return null;
  files.sort((a, b) {
    final left = a.episodeNumber ?? a.number;
    final right = b.episodeNumber ?? b.number;
    if (left != null && right != null && left != right) {
      return left.compareTo(right);
    }
    return a.name.compareTo(b.name);
  });
  return PreparedPlayerSource(
    sessionId: downloadedSourceSessionId(
      animeId,
      magnet,
      sharedFileIndex: sharedFileIndex,
    ),
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
