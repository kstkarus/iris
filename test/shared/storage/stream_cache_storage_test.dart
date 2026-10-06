import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/storage/stream_cache_storage.dart';

void main() {
  late Directory root;
  late Directory cacheDirectory;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('iris_stream_cache_test_');
    cacheDirectory = Directory('${root.path}${Platform.pathSeparator}stream');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File> writeFile(String name, int bytes) async {
    final file = File('${cacheDirectory.path}${Platform.pathSeparator}$name');
    await file.parent.create(recursive: true);
    return file.writeAsBytes(List.filled(bytes, 1));
  }

  test('prepare wipes leftovers from a previous run only once', () async {
    await writeFile('old${Platform.pathSeparator}episode.mkv', 32);
    final storage = StreamCacheStorage(directory: cacheDirectory);

    await storage.prepare();
    expect(await storage.sizeBytes(), 0);
    expect(await cacheDirectory.exists(), isTrue);

    await writeFile('current.mkv', 16);
    await storage.prepare();
    expect(await storage.sizeBytes(), 16);
  });

  test('clear removes current data and keeps the folder', () async {
    final storage = StreamCacheStorage(directory: cacheDirectory);
    await storage.prepare();
    await writeFile('a${Platform.pathSeparator}b.mkv', 8);

    await storage.clear();

    expect(await storage.sizeBytes(), 0);
    expect(await cacheDirectory.exists(), isTrue);
  });
}
