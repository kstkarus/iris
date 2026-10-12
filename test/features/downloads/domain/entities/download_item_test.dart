import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/domain/entities/download_failure.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';

void main() {
  final createdAt = DateTime.utc(2026, 7, 11, 10);
  final completedAt = DateTime.utc(2026, 7, 11, 11);

  DownloadItem createItem() {
    return DownloadItem(
      id: 'hash:4',
      animeId: '154587',
      animeTitle: 'Sousou no Frieren',
      sourceTitle: 'Episode 1',
      magnet: 'magnet:?xt=urn:btih:hash',
      fileIndex: 4,
      fileName: 'episode-01.mkv',
      relativePath: 'release/episode-01.mkv',
      localPath: '/downloads/hash/episode-01.mkv',
      totalBytes: 1024,
      downloadedBytes: 512,
      downloadRateBytesPerSecond: 128,
      peers: 3,
      status: DownloadStatus.downloading,
      errorMessage: 'temporary failure',
      createdAt: createdAt,
      completedAt: completedAt,
    );
  }

  test('progress is the loaded share, kept within 0 and 1', () {
    expect(createItem().progress, 0.5);
    expect(createItem().copyWith(totalBytes: 0).progress, 0);
    expect(createItem().copyWith(downloadedBytes: 2048).progress, 1);
  });

  test('uses value equality for all fields', () {
    expect(createItem(), createItem());
    expect(createItem().hashCode, createItem().hashCode);
  });

  test('copyWith updates fields and can clear nullable values', () {
    final updated = createItem().copyWith(
      downloadedBytes: 1024,
      downloadRateBytesPerSecond: 0,
      peers: 0,
      status: DownloadStatus.completed,
      errorMessage: null,
      completedAt: null,
    );

    expect(updated.downloadedBytes, 1024);
    expect(updated.downloadRateBytesPerSecond, 0);
    expect(updated.peers, 0);
    expect(updated.status, DownloadStatus.completed);
    expect(updated.errorMessage, isNull);
    expect(updated.completedAt, isNull);
    expect(updated.id, createItem().id);
  });

  test('an online release link makes an online episode', () {
    expect(createItem().isOnline, isFalse);
    expect(
      createItem().copyWith(magnet: 'online:anilibria/9542?anime=1').isOnline,
      isTrue,
    );
  });

  test('a failed online episode says whether a retry can help', () {
    DownloadFailure? failureOf(String message) => createItem()
        .copyWith(status: DownloadStatus.failed, errorMessage: message)
        .failure;

    expect(
      failureOf(downloadConnectionLostMessage),
      DownloadFailure.connectionLost,
    );
    expect(
      failureOf(downloadNotDownloadableMessage),
      DownloadFailure.notDownloadable,
    );
  });
}
