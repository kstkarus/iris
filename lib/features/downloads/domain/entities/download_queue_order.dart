import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';

/// Reorders the current waiting files. Stale ids are ignored, new files stay
/// at the end, and active, paused or deleting files keep their current slots.
List<DownloadItem> reorderQueuedDownloads(
  List<DownloadItem> downloads,
  List<String> ids, {
  Set<String> deletingIds = const {},
}) {
  bool waiting(DownloadItem item) =>
      item.status == DownloadStatus.queued && !deletingIds.contains(item.id);
  final remaining = {
    for (final item in downloads)
      if (waiting(item)) item.id: item,
  };
  final ordered = <DownloadItem>[
    for (final id in ids) ?remaining.remove(id),
    ...remaining.values,
  ].iterator;
  return [
    for (final item in downloads)
      if (waiting(item) && ordered.moveNext()) ordered.current else item,
  ];
}
