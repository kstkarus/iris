import 'dart:async';
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

    expect(await storage.clear(), isTrue);

    expect(await storage.sizeBytes(), 0);
    expect(await cacheDirectory.exists(), isTrue);
  });

  test('a clear before prepare counts as the wipe', () async {
    await writeFile('old${Platform.pathSeparator}episode.mkv', 32);
    final storage = StreamCacheStorage(directory: cacheDirectory);

    await storage.clear();
    await writeFile('current.mkv', 16);
    await storage.prepare();

    expect(await storage.sizeBytes(), 16);
  });

  test('prepare waits for a clear that is still deleting', () async {
    await writeFile('old${Platform.pathSeparator}episode.mkv', 32);
    final gate = Completer<void>();
    final storage = StreamCacheStorage(
      directory: cacheDirectory,
      delete: (entity) async {
        await gate.future;
        await entity.delete(recursive: true);
      },
    );
    var prepared = false;

    final clearing = storage.clear();
    final preparing = storage.prepare().then((_) {
      prepared = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(prepared, isFalse);

    gate.complete();
    expect(await clearing, isTrue);
    await preparing;
    expect(prepared, isTrue);
    expect(await storage.sizeBytes(), 0);
  });

  test('clear reports false when an entry cannot be deleted', () async {
    final storage = StreamCacheStorage(
      directory: cacheDirectory,
      delete: (entity) async {
        if (entity.path.endsWith('locked')) {
          throw FileSystemException('Still in use.', entity.path);
        }
        await entity.delete(recursive: true);
      },
    );
    await writeFile('free${Platform.pathSeparator}a.mkv', 8);
    await writeFile('locked${Platform.pathSeparator}b.mkv', 8);

    expect(await storage.clear(), isFalse);

    expect(await storage.sizeBytes(), 8);
    expect(await cacheDirectory.exists(), isTrue);
  });

  test(
    'clear reports false while a file is still open',
    () async {
      final file = await writeFile(
        'held${Platform.pathSeparator}episode.mkv',
        8,
      );
      final handle = await file.open();
      final storage = StreamCacheStorage(directory: cacheDirectory);
      try {
        expect(await storage.clear(), isFalse);
        expect(await file.exists(), isTrue);
      } finally {
        await handle.close();
      }
    },
    skip: Platform.isWindows
        ? false
        : 'Only Windows refuses to delete open files.',
  );
}
