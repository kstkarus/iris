import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/data/models/download_item_model.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';

void main() {
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

  test('persists relative paths and reads legacy absolute paths', () {
    final json = DownloadItemModel.toJson(item);
    final restored = DownloadItemModel.fromJson(json);

    expect(restored, item.copyWith(localPath: ''));
    expect(json, isNot(contains('localPath')));
    expect(json['status'], 'completed');

    json['localPath'] = item.localPath;
    expect(DownloadItemModel.fromJson(json), item);
  });

  test('rejects rooted and escaping paths on both mobile and desktop', () {
    for (final entry in [
      for (final id in [
        '',
        '.',
        '..',
        '../outside',
        r'..\outside',
        '/root',
        r'C:\root',
        'C:root',
        'nested/id',
        'bad\u0000id',
      ])
        MapEntry('id', id),
      for (final relative in [
        '../outside',
        r'..\outside',
        'folder/../../outside',
        r'folder\..\..\outside',
        '/root/file.mkv',
        r'C:\root\file.mkv',
        'C:relative.mkv',
        'bad\u0000file',
      ])
        MapEntry('relativePath', relative),
    ]) {
      final json = DownloadItemModel.toJson(item)..[entry.key] = entry.value;
      expect(
        () => DownloadItemModel.fromJson(json),
        throwsA(isA<FormatException>()),
        reason: '${entry.key}: ${entry.value}',
      );
    }
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
