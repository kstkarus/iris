import 'package:flutter_test/flutter_test.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_queue_order.dart';

void main() {
  test(
    'a stale order only changes the current waiting slots and keeps new arrivals',
    () {
      DownloadItem item(String id, DownloadStatus status) => DownloadItem(
        id: id,
        animeId: '1',
        animeTitle: 'Anime',
        sourceTitle: 'Dub',
        magnet: 'magnet',
        fileIndex: 0,
        fileName: '$id.mkv',
        relativePath: '$id.mkv',
        localPath: '/downloads/$id.mkv',
        totalBytes: 100,
        downloadedBytes: 40,
        downloadRateBytesPerSecond: 5,
        peers: 2,
        status: status,
        createdAt: DateTime(2026),
      );
      final current = [
        item('active', DownloadStatus.downloading),
        item('a', DownloadStatus.queued),
        item('paused', DownloadStatus.paused),
        item('b', DownloadStatus.queued),
        item('deleting', DownloadStatus.queued),
        item('failed', DownloadStatus.failed),
        item('done', DownloadStatus.completed),
        item('new', DownloadStatus.queued),
      ];
      final reordered = reorderQueuedDownloads(
        current,
        ['done', 'b', 'paused', 'gone', 'b', 'deleting', 'active', 'a'],
        deletingIds: {'deleting'},
      );
      expect(reordered.map((item) => item.id), [
        'active',
        'b',
        'paused',
        'a',
        'deleting',
        'failed',
        'done',
        'new',
      ]);
      expect(reordered.toSet(), current.toSet());
      for (final value in reordered) {
        expect(
          value,
          same(current.singleWhere((original) => original.id == value.id)),
        );
      }
      expect(current[1].id, 'a');
      expect(reorderQueuedDownloads(current, []), current);
    },
  );
}
