import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/data/datasources/download_registry_data_source.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';

void main() {
  late Directory temporaryDirectory;
  late File registryFile;
  late DownloadRegistryDataSource dataSource;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'iris_download_registry_test_',
    );
    registryFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}downloads.json',
    );
    dataSource = DownloadRegistryDataSource(registryFile: registryFile);
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('returns an empty list when the registry does not exist', () async {
    expect(await dataSource.readDownloads(), isEmpty);
  });

  test('writes and restores domain items', () async {
    final item = _createItem();

    await dataSource.writeDownloads([item]);

    expect(await dataSource.readDownloads(), [item]);
    expect(await File('${registryFile.path}.tmp').exists(), isFalse);
    expect(await File('${registryFile.path}.bak').exists(), isFalse);
  });

  test('replaces an existing registry', () async {
    await dataSource.writeDownloads([_createItem()]);
    final replacement = _createItem().copyWith(
      id: 'replacement',
      status: DownloadStatus.paused,
    );

    await dataSource.writeDownloads([replacement]);

    expect(await dataSource.readDownloads(), [replacement]);
  });

  test('returns an empty list for malformed JSON', () async {
    await registryFile.writeAsString('{broken json');

    expect(await dataSource.readDownloads(), isEmpty);
  });

  test('skips damaged entries while preserving valid ones', () async {
    final validItem = _createItem();
    await dataSource.writeDownloads([validItem]);
    final validJson = await registryFile.readAsString();
    final damagedEntry = validJson.substring(1, validJson.length - 1);
    await registryFile.writeAsString('[$damagedEntry,{"id":12}]');

    expect(await dataSource.readDownloads(), [validItem]);
  });

  test('recovers from a backup left by an interrupted replacement', () async {
    final item = _createItem();
    await dataSource.writeDownloads([item]);
    await registryFile.rename('${registryFile.path}.bak');

    expect(await dataSource.readDownloads(), [item]);

    final replacement = item.copyWith(id: 'replacement');
    await dataSource.writeDownloads([replacement]);
    expect(await dataSource.readDownloads(), [replacement]);
  });
}

DownloadItem _createItem() {
  return DownloadItem(
    id: 'hash:1',
    animeId: '154587',
    animeTitle: 'Sousou no Frieren',
    sourceTitle: 'Episode 1',
    magnet: 'magnet:?xt=urn:btih:hash',
    fileIndex: 1,
    fileName: 'episode-01.mkv',
    relativePath: 'release/episode-01.mkv',
    localPath: '/downloads/hash/episode-01.mkv',
    totalBytes: 1024,
    downloadedBytes: 512,
    downloadRateBytesPerSecond: 128,
    peers: 3,
    status: DownloadStatus.downloading,
    createdAt: DateTime.utc(2026, 7, 11, 10),
  );
}
