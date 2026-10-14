import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/shared/online/online_source_link.dart';
import 'package:iris/shared/torrent/torrent_key.dart';

/// A catalog title, or one unlinked release. Names are not identities.
String downloadTitleKey(DownloadItem item) => item.animeId.isNotEmpty
    ? 'anime:${item.animeId}'
    : downloadSourceKey(item.magnet);

String downloadSourceKey(String magnet) {
  final online = OnlineSourceLink.tryParse(magnet);
  if (online != null) return 'online:${online.provider}/${online.releaseId}';
  return torrentKeyFromMagnet(magnet);
}

class DownloadTitle {
  DownloadTitle(this.key, List<DownloadItem> items)
    : items = List.unmodifiable(items);

  final String key;
  final List<DownloadItem> items;
  String get name => items.first.animeTitle.isNotEmpty
      ? items.first.animeTitle
      : items.first.sourceTitle;
  int count(DownloadStatus status) =>
      items.where((item) => item.status == status).length;
  bool get active => items.any(
    (item) =>
        item.status == DownloadStatus.downloading ||
        item.status == DownloadStatus.queued,
  );
  DateTime get newest => items
      .map((item) => item.createdAt)
      .reduce((a, b) => a.isAfter(b) ? a : b);
}

List<DownloadTitle> downloadTitles(List<DownloadItem> items) {
  final groups = <String, List<DownloadItem>>{};
  for (final item in items) {
    groups.putIfAbsent(downloadTitleKey(item), () => []).add(item);
  }
  return [
    for (final entry in groups.entries) DownloadTitle(entry.key, entry.value),
  ]..sort((a, b) {
    if (a.active != b.active) return a.active ? -1 : 1;
    return b.newest.compareTo(a.newest);
  });
}
