import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/data/models/download_item_model.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';

void main() {
  test('round-trips a domain item through JSON', () {
    final item = DownloadItem(
      id: 'hash:2',
      animeId: '1',
      animeTitle: 'Anime',
      sourceTitle: 'Release',
      magnet: 'magnet:?xt=urn:btih:hash',
      fileIndex: 2,
      fileName: 'episode.mkv',
      relativePath: 'folder/episode.mkv',
      localPath: '/data/downloads/folder/episode.mkv',
      totalBytes: 2000,
      downloadedBytes: 2000,
      downloadRateBytesPerSecond: 0,
      peers: 0,
      status: DownloadStatus.completed,
      createdAt: DateTime.utc(2026, 7, 11, 9),
      completedAt: DateTime.utc(2026, 7, 11, 10),
      posterUrl: 'https://shikimori.one/posters/1/main.jpg',
      quality: 1080,
      videoHeight: 720,
    );

    final json = DownloadItemModel.toJson(item);
    final restored = DownloadItemModel.fromJson(json);

    expect(restored, item);
    expect(json['status'], 'completed');
  });

  test('reads older records without a poster URL', () {
    final json = DownloadItemModel.toJson(
      DownloadItem(
        id: 'id',
        animeId: '1',
        animeTitle: 'Anime',
        sourceTitle: 'Release',
        magnet: 'magnet',
        fileIndex: 0,
        fileName: 'episode.mkv',
        relativePath: 'episode.mkv',
        localPath: '/episode.mkv',
        totalBytes: 1,
        downloadedBytes: 0,
        downloadRateBytesPerSecond: 0,
        peers: 0,
        status: DownloadStatus.queued,
        createdAt: DateTime.utc(2026),
      ),
    )..remove('posterUrl');

    expect(DownloadItemModel.fromJson(json).posterUrl, isEmpty);
  });

  test(
    'reads old or invalid heights as unknown and rejects malformed types',
    () {
      final json = DownloadItemModel.toJson(
        DownloadItem(
          id: 'id',
          animeId: '1',
          animeTitle: 'Anime',
          sourceTitle: 'Release',
          magnet: 'magnet',
          fileIndex: 0,
          fileName: 'episode.mkv',
          relativePath: 'episode.mkv',
          localPath: '/episode.mkv',
          totalBytes: 1,
          downloadedBytes: 0,
          downloadRateBytesPerSecond: 0,
          peers: 0,
          status: DownloadStatus.queued,
          createdAt: DateTime.utc(2026),
        ),
      )..remove('videoHeight');
      expect(DownloadItemModel.fromJson(json).videoHeight, isNull);
      for (final invalid in [0, -1]) {
        json['videoHeight'] = invalid;
        expect(DownloadItemModel.fromJson(json).videoHeight, isNull);
      }
      json['videoHeight'] = '720';
      expect(
        () => DownloadItemModel.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('rejects an unknown download status', () {
    final json = DownloadItemModel.toJson(
      DownloadItem(
        id: 'id',
        animeId: '1',
        animeTitle: 'Anime',
        sourceTitle: 'Release',
        magnet: 'magnet',
        fileIndex: 0,
        fileName: 'episode.mkv',
        relativePath: 'episode.mkv',
        localPath: '/episode.mkv',
        totalBytes: 1,
        downloadedBytes: 0,
        downloadRateBytesPerSecond: 0,
        peers: 0,
        status: DownloadStatus.queued,
        createdAt: DateTime.utc(2026),
      ),
    );
    json['status'] = 'unknown';

    expect(
      () => DownloadItemModel.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });
}
