import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:iris/features/downloads/data/adapters/app_storage_usage_adapter.dart';
import 'package:iris/features/downloads/data/adapters/download_foreground_service_adapter.dart';
import 'package:iris/features/downloads/data/adapters/libtorrent_download_engine_adapter.dart';
import 'package:iris/features/downloads/data/datasources/download_registry_data_source.dart';
import 'package:iris/features/downloads/data/repositories/downloads_repository_impl.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/shared/storage/stream_cache_storage.dart';
import 'package:iris/shared/torrent/preparation_cancelled_exception.dart';
import 'package:iris/shared/torrent/torrent_activity_registry.dart';

void main() {
  late Directory temporaryDirectory;
  late Directory downloadsDirectory;
  late _FakeDownloadEngine engine;
  late _FakeForegroundService foregroundService;
  late TorrentActivityRegistry activityRegistry;
  late DownloadsRepositoryImpl repository;
  // Holds the create of a metadata folder while a test needs it open.
  Completer<void>? metadataFolderGate;
  var metadataFolderRequests = 0;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'iris_download_repository_test_',
    );
    downloadsDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}downloads',
    );
    engine = _FakeDownloadEngine();
    foregroundService = _FakeForegroundService();
    activityRegistry = TorrentActivityRegistry();
    metadataFolderGate = null;
    metadataFolderRequests = 0;
    repository = DownloadsRepositoryImpl(
      engine: engine,
      registry: DownloadRegistryDataSource(
        registryFile: File(
          '${temporaryDirectory.path}${Platform.pathSeparator}registry.json',
        ),
      ),
      downloadsDirectory: downloadsDirectory,
      foregroundService: foregroundService,
      storageUsageAdapter: const _FakeStorageUsageAdapter(),
      activityRegistry: activityRegistry,
      now: () => DateTime.utc(2026, 7, 11, 12),
      createMetadataFolder: (folder) async {
        metadataFolderRequests++;
        await metadataFolderGate?.future;
        await folder.create(recursive: true);
      },
    );
  });

  tearDown(() async {
    await repository.close();
    await engine.close();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('prepares only supported video files and disposes metadata', () async {
    final source = await repository.prepareSource(magnet: _magnet);

    expect(source.files, hasLength(2));
    expect(source.files.map((file) => file.name), [
      'episode-01.mkv',
      'episode-02.mp4',
    ]);
    expect(engine.addCalls.single.metadataOnly, isTrue);

    await repository.disposePreparedSource(sourceToken: source.sourceToken);

    expect(engine.removeCalls.single.deleteFiles, isTrue);
  });

  test(
    'queues one selected file and gives all other files zero priority',
    () async {
      final source = await repository.prepareSource(magnet: _magnet);
      final item = await repository.enqueueAndLeave(
        source: source,
        file: source.files[1],
        animeId: '154587',
        animeTitle: 'Sousou no Frieren',
        sourceTitle: 'Release',
      );

      await _waitFor(() => engine.priorityCalls.isNotEmpty);
      final downloads = await repository.currentDownloads();

      expect(item.fileIndex, 2);
      expect(downloads.single.status, DownloadStatus.downloading);
      expect(engine.addCalls.last.metadataOnly, isFalse);
      expect(engine.priorityCalls.single.priorities, [0, 0, 7, 0]);
      expect(engine.resumedTorrentIds, [engine.addCalls.last.id]);
      expect(foregroundService.startCount, 1);
    },
  );

  test('files queued from a picker that stays open start at once, one after '
      'another, and show by file', () async {
    final source = await repository.prepareSource(magnet: _magnet);
    final metadataTorrent = engine.addCalls.single;
    // The files are read: the picker lets its own torrent go.
    expect(
      engine.removeCalls,
      contains(_RemoveCall(metadataTorrent.id, deleteFiles: true)),
    );
    for (final file in source.files) {
      await repository.enqueueDownload(
        source: source,
        file: file,
        animeId: '154587',
        animeTitle: 'Sousou no Frieren',
        sourceTitle: 'Release',
      );
    }

    await _waitFor(() => engine.priorityCalls.isNotEmpty);
    expect(engine.addCalls.last.metadataOnly, isFalse);
    expect(engine.priorityCalls.single.priorities, [7, 0, 0, 0]);
    final shown = await repository.watchSourceDownloads(magnet: _magnet).first;
    expect(shown.keys, unorderedEquals(source.files.map((file) => file.index)));
    expect(shown.values.map((item) => item.status), [
      DownloadStatus.downloading,
      DownloadStatus.queued,
    ]);
    expect(
      await repository
          .watchSourceDownloads(magnet: 'magnet:?xt=urn:btih:0011223344556677')
          .first,
      isEmpty,
    );

    // Leaving the picker removes nothing more.
    final removed = engine.removeCalls.length;
    await repository.disposePreparedSource(sourceToken: source.sourceToken);
    expect(engine.removeCalls, hasLength(removed));
  });

  test('two pickers of one torrent opened together both get its files, and '
      'its metadata torrent goes once', () async {
    engine.metadataGate = Completer<void>();
    final first = repository.prepareSource(magnet: _magnet);
    await _waitFor(() => engine.addCalls.isNotEmpty);
    // The second borrows the torrent the first is still reading.
    final second = repository.prepareSource(magnet: _magnet);
    await Future<void>.delayed(Duration.zero);
    engine.metadataGate!.complete();

    final (a, b) = await (first, second).wait;

    expect(a.files, hasLength(2));
    expect(b.files, hasLength(2));
    final metadataId = engine.addCalls.single.id;
    expect(engine.removeCalls.where((call) => call.torrentId == metadataId), [
      _RemoveCall(metadataId, deleteFiles: true),
    ]);
    await repository.disposePreparedSource(sourceToken: a.sourceToken);
    await repository.disposePreparedSource(sourceToken: b.sourceToken);
    expect(
      engine.removeCalls.where((call) => call.torrentId == metadataId),
      hasLength(1),
    );
  });

  test('a file queued twice at once is one download', () async {
    final source = await repository.prepareSource(magnet: _magnet);
    Future<DownloadItem> enqueue() => repository.enqueueDownload(
      source: source,
      file: source.files.first,
      animeId: '154587',
      animeTitle: 'Sousou no Frieren',
      sourceTitle: 'Release',
    );

    final (first, second) = await (enqueue(), enqueue()).wait;

    expect(second.id, first.id);
    expect(await repository.currentDownloads(), hasLength(1));
    await _waitFor(() => engine.priorityCalls.isNotEmpty);
  });

  test('marks a finished file completed without deleting it', () async {
    final source = await repository.prepareSource(magnet: _magnet);
    final item = await repository.enqueueAndLeave(
      source: source,
      file: source.files.first,
      animeId: '154587',
      animeTitle: 'Sousou no Frieren',
      sourceTitle: 'Release',
    );
    await _waitFor(() => engine.priorityCalls.isNotEmpty);
    await File(item.localPath).parent.create(recursive: true);
    await File(item.localPath).writeAsBytes(List.filled(item.totalBytes, 1));

    final completed = repository.watchDownloads().firstWhere(
      (items) => items.any(
        (download) =>
            download.id == item.id &&
            download.status == DownloadStatus.completed,
      ),
    );
    final activeTorrentId = engine.addCalls.last.id;
    engine.emit({activeTorrentId: _torrent(isFinished: true)});
    await completed.timeout(const Duration(seconds: 2));

    final restored = await repository.findCompletedById(id: item.id);
    expect(restored, isNotNull);
    expect(await File(item.localPath).exists(), isTrue);
    expect(
      engine.removeCalls.last,
      _RemoveCall(activeTorrentId, deleteFiles: false),
    );
    expect(foregroundService.stopCount, greaterThan(0));

    // The finished torrent is already out of the engine.
    final removeCount = engine.removeCalls.length;
    expect(await repository.delete(id: item.id), isTrue);
    expect(engine.removeCalls, hasLength(removeCount));
    expect(await File(item.localPath).exists(), isFalse);
  });

  test(
    'pause preserves partial files and resume starts the item again',
    () async {
      final source = await repository.prepareSource(magnet: _magnet);
      final item = await repository.enqueueAndLeave(
        source: source,
        file: source.files.first,
        animeId: '154587',
        animeTitle: 'Sousou no Frieren',
        sourceTitle: 'Release',
      );
      await _waitFor(() => engine.priorityCalls.isNotEmpty);
      final firstTorrentId = engine.addCalls.last.id;

      await repository.pause(id: item.id);
      expect(
        (await repository.currentDownloads()).single.status,
        DownloadStatus.paused,
      );
      expect(engine.pausedTorrentIds, [firstTorrentId]);
      expect(
        engine.removeCalls.last,
        _RemoveCall(firstTorrentId, deleteFiles: false),
      );

      await repository.resume(id: item.id);
      await _waitFor(() => engine.priorityCalls.length == 2);
      expect(
        (await repository.currentDownloads()).single.status,
        DownloadStatus.downloading,
      );
      expect(engine.addCalls.last.id, isNot(firstTorrentId));
    },
  );

  test('reports offline and Android app storage usage', () async {
    await downloadsDirectory.create(recursive: true);
    await File(
      '${downloadsDirectory.path}${Platform.pathSeparator}video.mkv',
    ).writeAsBytes(List.filled(128, 0));
    final streamCacheDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}stream',
    );
    final leftover = File(
      '${streamCacheDirectory.path}${Platform.pathSeparator}episode.mkv',
    );
    await leftover.parent.create(recursive: true);
    await leftover.writeAsBytes(List.filled(16, 0));
    final androidRepository = DownloadsRepositoryImpl(
      engine: engine,
      registry: DownloadRegistryDataSource(
        registryFile: File(
          '${temporaryDirectory.path}${Platform.pathSeparator}android.json',
        ),
      ),
      downloadsDirectory: downloadsDirectory,
      foregroundService: foregroundService,
      storageUsageAdapter: const _FakeStorageUsageAdapter(),
      streamCache: StreamCacheStorage(directory: streamCacheDirectory),
      activityRegistry: activityRegistry,
    );
    addTearDown(androidRepository.close);

    final usage = await androidRepository.calculateStorageUsage();

    expect(usage.downloadsBytes, 128);
    // The stream folder Clear empties, not the whole system app cache (25).
    expect(usage.cacheBytes, 16);
    expect(usage.totalBytes, 300);
  });

  group('without system storage stats', () {
    late Directory streamCacheDirectory;
    late DownloadsRepositoryImpl desktopRepository;

    setUp(() {
      streamCacheDirectory = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}stream',
      );
      desktopRepository = DownloadsRepositoryImpl(
        engine: engine,
        registry: DownloadRegistryDataSource(
          registryFile: File(
            '${temporaryDirectory.path}${Platform.pathSeparator}desktop.json',
          ),
        ),
        downloadsDirectory: downloadsDirectory,
        foregroundService: foregroundService,
        storageUsageAdapter: const _FakeStorageUsageAdapter(usage: null),
        streamCache: StreamCacheStorage(directory: streamCacheDirectory),
        activityRegistry: activityRegistry,
      );
    });

    tearDown(() => desktopRepository.close());

    Future<void> writeStreamLeftover() async {
      final file = File(
        '${streamCacheDirectory.path}${Platform.pathSeparator}'
        'Show${Platform.pathSeparator}episode.mkv',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(List.filled(64, 0));
    }

    test('counts the stream cache and sums the total', () async {
      await downloadsDirectory.create(recursive: true);
      await File(
        '${downloadsDirectory.path}${Platform.pathSeparator}video.mkv',
      ).writeAsBytes(List.filled(128, 0));
      await writeStreamLeftover();

      final usage = await desktopRepository.calculateStorageUsage();

      expect(usage.downloadsBytes, 128);
      expect(usage.cacheBytes, 64);
      expect(usage.totalBytes, 192);
    });

    test('clears the stream cache but not while streaming', () async {
      await writeStreamLeftover();
      activityRegistry.acquireStreaming('abc');

      expect(await desktopRepository.clearCache(), isFalse);
      expect((await desktopRepository.calculateStorageUsage()).cacheBytes, 64);

      activityRegistry.releaseStreaming('abc');
      expect(await desktopRepository.clearCache(), isTrue);
      expect((await desktopRepository.calculateStorageUsage()).cacheBytes, 0);
      expect(await streamCacheDirectory.exists(), isTrue);
    });

    test('reports a cache that could not be fully cleared', () async {
      final stuckRepository = DownloadsRepositoryImpl(
        engine: engine,
        registry: DownloadRegistryDataSource(
          registryFile: File(
            '${temporaryDirectory.path}${Platform.pathSeparator}stuck.json',
          ),
        ),
        downloadsDirectory: downloadsDirectory,
        foregroundService: foregroundService,
        storageUsageAdapter: const _FakeStorageUsageAdapter(usage: null),
        streamCache: StreamCacheStorage(
          directory: streamCacheDirectory,
          delete: (entity) => Future<void>.error(
            FileSystemException('Still in use.', entity.path),
          ),
        ),
        activityRegistry: activityRegistry,
      );
      addTearDown(stuckRepository.close);
      await writeStreamLeftover();

      expect(await stuckRepository.clearCache(), isFalse);
    });
  });

  test('does not complete while wanted pieces are still missing even if raw '
      'done-bytes reach the file size', () async {
    final source = await repository.prepareSource(magnet: _magnet);
    final item = await repository.enqueueAndLeave(
      source: source,
      file: source.files.first,
      animeId: '154587',
      animeTitle: 'Sousou no Frieren',
      sourceTitle: 'Release',
    );
    await _waitFor(() => engine.priorityCalls.isNotEmpty);
    final activeTorrentId = engine.addCalls.last.id;

    engine.emit({activeTorrentId: _torrent(isFinished: false, progress: 0.5)});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final items = await repository.currentDownloads();

    expect(items.single.status, DownloadStatus.downloading);
    expect(items.single.downloadedBytes, item.totalBytes ~/ 2);
  });

  test('ignores engine state until the selected file is prioritized', () async {
    final source = await repository.prepareSource(magnet: _magnet);
    engine.metadataGate = Completer<void>();
    await repository.enqueueAndLeave(
      source: source,
      file: source.files.first,
      animeId: '154587',
      animeTitle: 'Sousou no Frieren',
      sourceTitle: 'Release',
    );
    await _waitFor(() => engine.addCalls.length == 2);
    final activeTorrentId = engine.addCalls.last.id;

    // Whole-torrent state before priorities are applied must not finish or
    // fail the download.
    engine.emit({activeTorrentId: _torrent(isFinished: true)});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      (await repository.currentDownloads()).single.status,
      DownloadStatus.downloading,
    );

    engine.metadataGate!.complete();
    await _waitFor(() => engine.priorityCalls.isNotEmpty);
    expect(
      (await repository.currentDownloads()).single.status,
      DownloadStatus.downloading,
    );
  });

  test('the service stays up from a finished item to the next queued one, '
      'and stops after the last', () async {
    const otherMagnet = 'magnet:?xt=urn:btih:0011223344556677';
    final first = await repository.prepareSource(magnet: _magnet);
    final second = await repository.prepareSource(magnet: otherMagnet);
    final firstItem = await repository.enqueueAndLeave(
      source: first,
      file: first.files.first,
      animeId: '1',
      animeTitle: 'First',
      sourceTitle: 'Release',
    );
    final secondItem = await repository.enqueueAndLeave(
      source: second,
      file: second.files.first,
      animeId: '2',
      animeTitle: 'Second',
      sourceTitle: 'Release',
    );
    await _waitFor(() => engine.priorityCalls.isNotEmpty);

    Future<void> finish(DownloadItem item) async {
      await File(item.localPath).parent.create(recursive: true);
      await File(item.localPath).writeAsBytes(List.filled(item.totalBytes, 1));
      engine.emit({engine.addCalls.last.id: _torrent(isFinished: true)});
    }

    await finish(firstItem);
    await _waitFor(() => engine.priorityCalls.length == 2);
    expect(foregroundService.stopCount, 0);
    expect(foregroundService.startCount, 2);

    await finish(secondItem);
    await _waitFor(() => foregroundService.stopCount == 1);
  });

  test(
    'pausing during the metadata wait starts the next queued item',
    () async {
      const otherMagnet = 'magnet:?xt=urn:btih:0011223344556677';
      final first = await repository.prepareSource(magnet: _magnet);
      final second = await repository.prepareSource(magnet: otherMagnet);
      engine.metadataGate = Completer<void>();
      final firstItem = await repository.enqueueAndLeave(
        source: first,
        file: first.files.first,
        animeId: '1',
        animeTitle: 'First',
        sourceTitle: 'Release',
      );
      await repository.enqueueAndLeave(
        source: second,
        file: second.files.first,
        animeId: '2',
        animeTitle: 'Second',
        sourceTitle: 'Release',
      );
      await _waitFor(() => engine.addCalls.length == 3);

      // Metadata for the first torrent never arrives; pausing must not leave
      // the queue blocked until the metadata timeout.
      engine.metadataGate = null;
      await repository.pause(id: firstItem.id);

      await _waitFor(() => engine.priorityCalls.isNotEmpty);
      expect(engine.addCalls.last.magnet, otherMagnet);
      final downloads = await repository.currentDownloads();
      expect(downloads.map((item) => item.status), [
        DownloadStatus.paused,
        DownloadStatus.downloading,
      ]);
    },
  );

  test('selection for a torrent that is downloading borrows it instead of '
      'adding a duplicate that would delete the download on dispose', () async {
    final source = await repository.prepareSource(magnet: _magnet);
    await repository.enqueueAndLeave(
      source: source,
      file: source.files.first,
      animeId: '154587',
      animeTitle: 'Sousou no Frieren',
      sourceTitle: 'Release',
    );
    await _waitFor(() => engine.priorityCalls.isNotEmpty);
    final activeTorrentId = engine.addCalls.last.id;
    final addCountBefore = engine.addCalls.length;
    final removeCountBefore = engine.removeCalls.length;

    final again = await repository.prepareSource(magnet: _magnet);
    expect(again.files, hasLength(2));
    expect(engine.addCalls, hasLength(addCountBefore));

    await repository.disposePreparedSource(sourceToken: again.sourceToken);
    expect(engine.removeCalls, hasLength(removeCountBefore));
    expect(
      engine.removeCalls,
      isNot(contains(_RemoveCall(activeTorrentId, deleteFiles: true))),
    );
  });

  test(
    'a queued download of a torrent a picker shows starts while it is open',
    () async {
      final source = await repository.prepareSource(magnet: _magnet);
      final item = await repository.enqueueAndLeave(
        source: source,
        file: source.files.first,
        animeId: '154587',
        animeTitle: 'Sousou no Frieren',
        sourceTitle: 'Release',
      );
      await _waitFor(() => engine.priorityCalls.isNotEmpty);
      await repository.pause(id: item.id);

      final selection = await repository.prepareSource(magnet: _magnet);
      final selectionTorrentId = engine.addCalls.last.id;
      await repository.resume(id: item.id);

      await _waitFor(() => engine.priorityCalls.length == 2);
      expect(engine.addCalls.last.id, isNot(selectionTorrentId));
      expect(
        (await repository.currentDownloads()).single.status,
        DownloadStatus.downloading,
      );
      await repository.disposePreparedSource(
        sourceToken: selection.sourceToken,
      );
    },
  );

  test('streaming the same torrent sends the active download back to the queue '
      'and resumes it afterwards', () async {
    final source = await repository.prepareSource(magnet: _magnet);
    await repository.enqueueAndLeave(
      source: source,
      file: source.files.first,
      animeId: '154587',
      animeTitle: 'Sousou no Frieren',
      sourceTitle: 'Release',
    );
    await _waitFor(() => engine.priorityCalls.isNotEmpty);
    final downloadTorrentId = engine.addCalls.last.id;

    activityRegistry.acquireStreaming('abcdef1234567890');

    // Released synchronously, without deleting partial files.
    expect(
      engine.removeCalls.last,
      _RemoveCall(downloadTorrentId, deleteFiles: false),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      (await repository.currentDownloads()).single.status,
      DownloadStatus.queued,
    );
    expect(engine.addCalls.last.id, downloadTorrentId);

    activityRegistry.releaseStreaming('abcdef1234567890');
    await _waitFor(() => engine.priorityCalls.length == 2);
    expect(engine.addCalls.last.id, isNot(downloadTorrentId));
    expect(
      (await repository.currentDownloads()).single.status,
      DownloadStatus.downloading,
    );
  });

  test(
    'streaming another torrent does not touch the active download',
    () async {
      final source = await repository.prepareSource(magnet: _magnet);
      await repository.enqueueAndLeave(
        source: source,
        file: source.files.first,
        animeId: '154587',
        animeTitle: 'Sousou no Frieren',
        sourceTitle: 'Release',
      );
      await _waitFor(() => engine.priorityCalls.isNotEmpty);
      final removeCount = engine.removeCalls.length;

      activityRegistry.acquireStreaming('ffffffffffffffff');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(engine.removeCalls, hasLength(removeCount));
      expect(
        (await repository.currentDownloads()).single.status,
        DownloadStatus.downloading,
      );
    },
  );

  test('a completion awaiting its notification does not overwrite a pause or '
      'the next download', () async {
    final firstSource = await repository.prepareSource(magnet: _magnet);
    final first = await repository.enqueueAndLeave(
      source: firstSource,
      file: firstSource.files.first,
      animeId: '1',
      animeTitle: 'First',
      sourceTitle: 'Release',
    );
    await _waitFor(() => engine.priorityCalls.isNotEmpty);
    final firstTorrentId = engine.addCalls.last.id;

    const otherMagnet = 'magnet:?xt=urn:btih:0011223344556677';
    final secondSource = await repository.prepareSource(magnet: otherMagnet);
    final second = await repository.enqueueAndLeave(
      source: secondSource,
      file: secondSource.files.first,
      animeId: '2',
      animeTitle: 'Second',
      sourceTitle: 'Release',
    );

    // The completion is still inside the notification update when the user
    // pauses; the queued item becomes active meanwhile.
    await File(first.localPath).parent.create(recursive: true);
    await File(first.localPath).writeAsBytes(List.filled(first.totalBytes, 1));
    foregroundService.updateGate = Completer<void>();
    engine.emit({firstTorrentId: _torrent(isFinished: true)});
    await _waitFor(() => foregroundService.updateCount == 1);
    await repository.pause(id: first.id);
    await _waitFor(() => engine.priorityCalls.length == 2);
    final secondTorrentId = engine.addCalls.last.id;
    final stopCount = foregroundService.stopCount;

    foregroundService.updateGate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final downloads = await repository.currentDownloads();
    expect(downloads.map((item) => item.status), [
      DownloadStatus.paused,
      DownloadStatus.downloading,
    ]);
    expect(foregroundService.stopCount, stopCount);
    expect(
      engine.removeCalls.where((call) => call.torrentId == secondTorrentId),
      isEmpty,
    );

    engine.emit({secondTorrentId: _torrent(isFinished: false, progress: 0.5)});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      (await repository.currentDownloads()).last.downloadedBytes,
      second.totalBytes ~/ 2,
    );
  });

  test('pausing while the start is creating the directory keeps the item '
      'paused', () async {
    final source = await repository.prepareSource(magnet: _magnet);
    final item = await repository.enqueueAndLeave(
      source: source,
      file: source.files.first,
      animeId: '154587',
      animeTitle: 'Sousou no Frieren',
      sourceTitle: 'Release',
    );

    await repository.pause(id: item.id);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      (await repository.currentDownloads()).single.status,
      DownloadStatus.paused,
    );
    expect(engine.addCalls.where((call) => !call.metadataOnly), isEmpty);
    expect(engine.liveTorrentIds, isEmpty);
  });

  test(
    'deleting while the start is creating the directory adds no torrent',
    () async {
      final source = await repository.prepareSource(magnet: _magnet);
      final item = await repository.enqueueAndLeave(
        source: source,
        file: source.files.first,
        animeId: '154587',
        animeTitle: 'Sousou no Frieren',
        sourceTitle: 'Release',
      );

      await repository.delete(id: item.id);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await repository.currentDownloads(), isEmpty);
      expect(engine.addCalls.where((call) => !call.metadataOnly), isEmpty);
      expect(engine.liveTorrentIds, isEmpty);
    },
  );

  test('streaming the same torrent while the start is creating the directory '
      'keeps the item queued', () async {
    final source = await repository.prepareSource(magnet: _magnet);
    await repository.enqueueAndLeave(
      source: source,
      file: source.files.first,
      animeId: '154587',
      animeTitle: 'Sousou no Frieren',
      sourceTitle: 'Release',
    );

    activityRegistry.acquireStreaming('abcdef1234567890');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(engine.addCalls.where((call) => !call.metadataOnly), isEmpty);
    expect(
      (await repository.currentDownloads()).single.status,
      DownloadStatus.queued,
    );

    activityRegistry.releaseStreaming('abcdef1234567890');
    await _waitFor(() => engine.priorityCalls.isNotEmpty);
    expect(
      (await repository.currentDownloads()).single.status,
      DownloadStatus.downloading,
    );
  });

  test(
    'pausing while the foreground service starts keeps the torrent stopped',
    () async {
      final source = await repository.prepareSource(magnet: _magnet);
      foregroundService.startGate = Completer<void>();
      final item = await repository.enqueueAndLeave(
        source: source,
        file: source.files.first,
        animeId: '154587',
        animeTitle: 'Sousou no Frieren',
        sourceTitle: 'Release',
      );
      await _waitFor(() => foregroundService.startCount == 1);

      await repository.pause(id: item.id);
      foregroundService.startGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        (await repository.currentDownloads()).single.status,
        DownloadStatus.paused,
      );
      expect(engine.priorityCalls, isEmpty);
      expect(engine.liveTorrentIds, isEmpty);
    },
  );

  test(
    'a folder that cannot be deleted keeps the record, stopped, to delete again',
    () async {
      final source = await repository.prepareSource(magnet: _magnet);
      final item = await repository.enqueueAndLeave(
        source: source,
        file: source.files.first,
        animeId: '154587',
        animeTitle: 'Sousou no Frieren',
        sourceTitle: 'Release',
      );
      await _waitFor(() => engine.priorityCalls.isNotEmpty);
      await File(item.localPath).parent.create(recursive: true);
      // An open handle keeps Windows from removing the folder.
      final lock = await File(item.localPath).open(mode: FileMode.write);
      try {
        expect(await repository.delete(id: item.id), isFalse);

        final downloads = await repository.currentDownloads();
        // Not failed: its action would be Retry, which loads the file again.
        expect(downloads.single.status, DownloadStatus.paused);
        expect(downloads.single.errorMessage, isNull);
        expect(downloads.single.downloadRateBytesPerSecond, 0);
      } finally {
        await lock.close();
      }

      expect(await repository.delete(id: item.id), isTrue);
      expect(await repository.currentDownloads(), isEmpty);
    },
    skip: Platform.isWindows
        ? false
        : 'Needs a Windows file lock to keep the folder undeletable.',
  );

  test('cancelling the metadata wait removes its torrent and folder', () async {
    engine.metadataGate = Completer<void>();
    final cancelled = Completer<void>();
    final pending = repository.prepareSource(
      magnet: _magnet,
      cancelled: cancelled.future,
    );
    await _waitFor(() => engine.addCalls.isNotEmpty);
    final added = engine.addCalls.single;
    expect(added.metadataOnly, isTrue);

    cancelled.complete();

    await expectLater(pending, throwsA(isA<PreparationCancelledException>()));
    expect(engine.removeCalls.single, _RemoveCall(added.id, deleteFiles: true));
    expect(engine.liveTorrentIds, isEmpty);
    expect(await Directory(added.savePath).exists(), isFalse);
  });

  test('cancelling the wait for a borrowed torrent removes nothing', () async {
    final source = await repository.prepareSource(magnet: _magnet);
    await repository.enqueueAndLeave(
      source: source,
      file: source.files.first,
      animeId: '154587',
      animeTitle: 'Sousou no Frieren',
      sourceTitle: 'Release',
    );
    await _waitFor(() => engine.priorityCalls.isNotEmpty);
    final activeTorrentId = engine.addCalls.last.id;
    final removeCount = engine.removeCalls.length;
    engine.metadataGate = Completer<void>();
    final cancelled = Completer<void>();

    final pending = repository.prepareSource(
      magnet: _magnet,
      cancelled: cancelled.future,
    );
    cancelled.complete();

    await expectLater(pending, throwsA(isA<PreparationCancelledException>()));
    expect(engine.removeCalls, hasLength(removeCount));
    expect(engine.liveTorrentIds, contains(activeTorrentId));
    expect(
      (await repository.currentDownloads()).single.status,
      DownloadStatus.downloading,
    );
  });

  test(
    'a file queued under its base32 id is found again by its hex key',
    () async {
      const base32Magnet =
          'magnet:?xt=urn:btih:AZOENEO6QT4WJYKDCA5TXUG6C67FX7IK';
      final legacy = DownloadItem(
        id: 'azoeneo6qt4wjykdca5txug6c67fx7ik-0',
        animeId: '154587',
        animeTitle: 'Sousou no Frieren',
        sourceTitle: 'Release',
        magnet: base32Magnet,
        fileIndex: 0,
        fileName: 'episode-01.mkv',
        relativePath: 'episode-01.mkv',
        localPath: path.join(downloadsDirectory.path, 'episode-01.mkv'),
        totalBytes: 100,
        downloadedBytes: 10,
        downloadRateBytesPerSecond: 0,
        peers: 0,
        status: DownloadStatus.paused,
        createdAt: DateTime.utc(2026, 9, 1),
      );
      await DownloadRegistryDataSource(
        registryFile: File(
          '${temporaryDirectory.path}${Platform.pathSeparator}registry.json',
        ),
      ).writeDownloads([legacy]);

      final source = await repository.prepareSource(magnet: base32Magnet);
      final item = await repository.enqueueAndLeave(
        source: source,
        file: source.files.first,
        animeId: '154587',
        animeTitle: 'Sousou no Frieren',
        sourceTitle: 'Release',
      );

      expect(item.id, legacy.id);
      expect(await repository.currentDownloads(), hasLength(1));
    },
  );

  test('concurrent first restores read the registry once', () async {
    final registry = _CountingRegistry(
      registryFile: File(
        '${temporaryDirectory.path}${Platform.pathSeparator}concurrent.json',
      ),
    );
    final concurrentRepository = DownloadsRepositoryImpl(
      engine: engine,
      registry: registry,
      downloadsDirectory: downloadsDirectory,
      foregroundService: foregroundService,
      storageUsageAdapter: const _FakeStorageUsageAdapter(),
      activityRegistry: activityRegistry,
    );
    addTearDown(concurrentRepository.close);

    await Future.wait([
      concurrentRepository.restore(),
      concurrentRepository.restore(),
    ]);
    await concurrentRepository.restore();

    expect(registry.reads, 1);
  });

  test('a downloads list that cannot be written holds up nothing', () async {
    final registry = _RefusingRegistry(
      registryFile: File(
        '${temporaryDirectory.path}${Platform.pathSeparator}full_disk.json',
      ),
    );
    final fullDiskRepository = DownloadsRepositoryImpl(
      engine: engine,
      registry: registry,
      downloadsDirectory: downloadsDirectory,
      foregroundService: foregroundService,
      storageUsageAdapter: const _FakeStorageUsageAdapter(),
      activityRegistry: activityRegistry,
    );
    addTearDown(fullDiskRepository.close);

    await fullDiskRepository.restore();
    final source = await fullDiskRepository.prepareSource(magnet: _magnet);
    await fullDiskRepository.enqueueAndLeave(
      source: source,
      file: source.files[1],
      animeId: '154587',
      animeTitle: 'Sousou no Frieren',
      sourceTitle: 'Release',
    );

    // Only the selected file is wanted, as with a list that saves.
    await _waitFor(() => engine.priorityCalls.isNotEmpty);
    expect(engine.priorityCalls.single.priorities, [0, 0, 7, 0]);
    expect(registry.refused, greaterThan(0));
    final downloads = await fullDiskRepository.currentDownloads();
    expect(downloads.single.status, DownloadStatus.downloading);
  });

  test(
    'a selection waits until a closing player releases the torrent',
    () async {
      await repository.restore();
      activityRegistry.acquireStreaming('abcdef1234567890');

      final pending = repository.prepareSource(magnet: _magnet);
      await pumpEventQueue();
      // Not even the folder: the wait comes before anything is created.
      expect(metadataFolderRequests, 0);
      expect(engine.addCalls, isEmpty);

      activityRegistry.releaseStreaming('abcdef1234567890');
      final source = await pending;

      expect(source.files, isNotEmpty);
      expect(engine.addCalls.single.metadataOnly, isTrue);
    },
  );

  test('leaving a selection that waits for a player adds nothing', () async {
    await repository.restore();
    activityRegistry.acquireStreaming('abcdef1234567890');
    final cancelled = Completer<void>();

    final pending = repository.prepareSource(
      magnet: _magnet,
      cancelled: cancelled.future,
    );
    await pumpEventQueue();
    cancelled.complete();

    await expectLater(pending, throwsA(isA<PreparationCancelledException>()));
    activityRegistry.releaseStreaming('abcdef1234567890');
    await pumpEventQueue();
    expect(metadataFolderRequests, 0);
    expect(engine.addCalls, isEmpty);
  });

  test('a player that starts while a selection creates its folder is waited '
      'for', () async {
    await repository.restore();
    final gate = metadataFolderGate = Completer<void>();
    final pending = repository.prepareSource(magnet: _magnet);
    await _waitFor(() => metadataFolderRequests == 1);

    activityRegistry.acquireStreaming('abcdef1234567890');
    gate.complete();
    final metadataRoot = Directory(
      '${downloadsDirectory.path}${Platform.pathSeparator}.metadata',
    );
    await _waitFor(
      () => metadataRoot.existsSync() && metadataRoot.listSync().isNotEmpty,
    );
    await pumpEventQueue();
    expect(engine.addCalls, isEmpty);

    activityRegistry.releaseStreaming('abcdef1234567890');
    await pending;
    expect(engine.addCalls.single.metadataOnly, isTrue);
  });

  test(
    'a queued download of a torrent waits for a source still preparing it',
    () async {
      const otherMagnet = 'magnet:?xt=urn:btih:0011223344556677';
      final active = await repository.prepareSource(magnet: otherMagnet);
      final activeItem = await repository.enqueueAndLeave(
        source: active,
        file: active.files.first,
        animeId: '1',
        animeTitle: 'Active',
        sourceTitle: 'Release',
      );
      await _waitFor(() => engine.priorityCalls.isNotEmpty);
      final queued = await repository.prepareSource(magnet: _magnet);
      await repository.enqueueAndLeave(
        source: queued,
        file: queued.files.first,
        animeId: '2',
        animeTitle: 'Queued',
        sourceTitle: 'Release',
      );

      // The other download holds the queue, so the item waits for it.
      engine.metadataGate = Completer<void>();
      final cancelled = Completer<void>();
      final addCountBefore = engine.addCalls.length;
      final pending = repository.prepareSource(
        magnet: _magnet,
        cancelled: cancelled.future,
      );
      await _waitFor(() => engine.addCalls.length == addCountBefore + 1);

      await repository.pause(id: activeItem.id);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        engine.addCalls.where(
          (call) => call.magnet == _magnet && !call.metadataOnly,
        ),
        isEmpty,
      );
      expect((await repository.currentDownloads()).map((item) => item.status), [
        DownloadStatus.paused,
        DownloadStatus.queued,
      ]);

      engine.metadataGate = null;
      cancelled.complete();
      await expectLater(pending, throwsA(isA<PreparationCancelledException>()));
      await _waitFor(() => engine.priorityCalls.length == 2);
      expect((await repository.currentDownloads()).map((item) => item.status), [
        DownloadStatus.paused,
        DownloadStatus.downloading,
      ]);
    },
  );

  test(
    'a metadata folder that cannot be removed does not stop the queue',
    () async {
      const otherMagnet = 'magnet:?xt=urn:btih:0011223344556677';
      final active = await repository.prepareSource(magnet: otherMagnet);
      final activeItem = await repository.enqueueAndLeave(
        source: active,
        file: active.files.first,
        animeId: '1',
        animeTitle: 'Active',
        sourceTitle: 'Release',
      );
      await _waitFor(() => engine.priorityCalls.isNotEmpty);
      final queued = await repository.prepareSource(magnet: _magnet);
      await repository.enqueueAndLeave(
        source: queued,
        file: queued.files.first,
        animeId: '2',
        animeTitle: 'Queued',
        sourceTitle: 'Release',
      );
      final selection = await repository.prepareSource(magnet: _magnet);
      final selectionFolder = engine.addCalls.last.savePath;
      await repository.pause(id: activeItem.id);

      // An open handle keeps Windows from removing the folder.
      final lock = await File(
        path.join(selectionFolder, 'lock'),
      ).open(mode: FileMode.write);
      try {
        await repository.disposePreparedSource(
          sourceToken: selection.sourceToken,
        );
        expect(await Directory(selectionFolder).exists(), isTrue);
        await _waitFor(() => engine.priorityCalls.length == 2);
      } finally {
        await lock.close();
      }

      expect((await repository.currentDownloads()).map((item) => item.status), [
        DownloadStatus.paused,
        DownloadStatus.downloading,
      ]);
    },
    skip: Platform.isWindows
        ? false
        : 'Needs a Windows file lock to keep the folder undeletable.',
  );

  test('a queued download whose folder cannot be created fails and the queue '
      'moves on', () async {
    const otherMagnet = 'magnet:?xt=urn:btih:0011223344556677';
    const nextMagnet = 'magnet:?xt=urn:btih:8899AABBCCDDEEFF';
    final active = await repository.prepareSource(magnet: otherMagnet);
    final activeItem = await repository.enqueueAndLeave(
      source: active,
      file: active.files.first,
      animeId: '1',
      animeTitle: 'Active',
      sourceTitle: 'Release',
    );
    await _waitFor(() => engine.priorityCalls.isNotEmpty);
    final blocked = await repository.prepareSource(magnet: _magnet);
    final blockedItem = await repository.enqueueAndLeave(
      source: blocked,
      file: blocked.files.first,
      animeId: '2',
      animeTitle: 'Blocked',
      sourceTitle: 'Release',
    );
    final next = await repository.prepareSource(magnet: nextMagnet);
    await repository.enqueueAndLeave(
      source: next,
      file: next.files.first,
      animeId: '3',
      animeTitle: 'Next',
      sourceTitle: 'Release',
    );

    // A file where the folder of the blocked item must be created.
    final blockedFolder = path.join(
      downloadsDirectory.path,
      'content',
      blockedItem.id,
    );
    await Directory(blockedFolder).delete(recursive: true);
    await File(blockedFolder).writeAsString('not a folder');

    await repository.pause(id: activeItem.id);
    await _waitFor(() => engine.priorityCalls.length == 2);

    final downloads = await repository.currentDownloads();
    expect(downloads.map((item) => item.status), [
      DownloadStatus.paused,
      DownloadStatus.failed,
      DownloadStatus.downloading,
    ]);
    expect(downloads[1].errorMessage, 'Unable to start the download.');
  });

  test('a download that starts while a selection creates its folder is '
      'borrowed, not added twice', () async {
    const otherMagnet = 'magnet:?xt=urn:btih:0011223344556677';
    final active = await repository.prepareSource(magnet: otherMagnet);
    final activeItem = await repository.enqueueAndLeave(
      source: active,
      file: active.files.first,
      animeId: '1',
      animeTitle: 'Active',
      sourceTitle: 'Release',
    );
    await _waitFor(() => engine.priorityCalls.isNotEmpty);
    final queued = await repository.prepareSource(magnet: _magnet);
    await repository.enqueueAndLeave(
      source: queued,
      file: queued.files.first,
      animeId: '2',
      animeTitle: 'Queued',
      sourceTitle: 'Release',
    );

    // The selection's folder is created only after the queued download has
    // started, which is when a second add would meet the download's torrent.
    metadataFolderGate = Completer<void>();
    final addCountBefore = engine.addCalls.length;
    final selection = repository.prepareSource(magnet: _magnet);
    await repository.pause(id: activeItem.id);
    await _waitFor(() => engine.priorityCalls.length == 2);
    metadataFolderGate!.complete();
    final source = await selection;

    final addedForKey = engine.addCalls
        .skip(addCountBefore)
        .where((call) => call.magnet == _magnet)
        .toList();
    expect(addedForKey.map((call) => call.metadataOnly), [false]);
    expect(source.files, hasLength(2));

    final removeCount = engine.removeCalls.length;
    await repository.disposePreparedSource(sourceToken: source.sourceToken);
    expect(engine.removeCalls.skip(removeCount), isEmpty);
    expect(engine.liveTorrentIds, contains(addedForKey.single.id));
    expect((await repository.currentDownloads()).map((item) => item.status), [
      DownloadStatus.paused,
      DownloadStatus.downloading,
    ]);
    final metadataFolder = Directory(
      path.join(downloadsDirectory.path, '.metadata'),
    );
    final leftovers = await metadataFolder.exists()
        ? await metadataFolder.list().toList()
        : <FileSystemEntity>[];
    expect(leftovers, isEmpty);
  });
}

const _magnet = 'magnet:?xt=urn:btih:ABCDEF1234567890';

class _FakeDownloadEngine implements LibtorrentDownloadEngineAdapter {
  final StreamController<Map<int, DownloadEngineTorrent>> _controller =
      StreamController<Map<int, DownloadEngineTorrent>>.broadcast();
  final List<_AddCall> addCalls = [];
  final List<_RemoveCall> removeCalls = [];
  final List<_PriorityCall> priorityCalls = [];
  final List<int> pausedTorrentIds = [];
  final List<int> resumedTorrentIds = [];
  final Set<int> liveTorrentIds = {};
  int _nextId = 0;

  static const files = [
    DownloadEngineFile(
      index: 0,
      name: 'episode-01.mkv',
      relativePath: 'release/episode-01.mkv',
      size: 64,
      isStreamable: true,
    ),
    DownloadEngineFile(
      index: 1,
      name: 'cover.jpg',
      relativePath: 'release/cover.jpg',
      size: 10,
      isStreamable: false,
    ),
    DownloadEngineFile(
      index: 2,
      name: 'episode-02.mp4',
      relativePath: 'release/episode-02.mp4',
      size: 80,
      isStreamable: true,
    ),
    DownloadEngineFile(
      index: 3,
      name: 'notes.txt',
      relativePath: 'release/notes.txt',
      size: 5,
      isStreamable: false,
    ),
  ];

  @override
  int addMagnet({
    required String magnet,
    required String savePath,
    required bool metadataOnly,
  }) {
    final id = ++_nextId;
    addCalls.add(
      _AddCall(
        id: id,
        magnet: magnet,
        savePath: savePath,
        metadataOnly: metadataOnly,
      ),
    );
    liveTorrentIds.add(id);
    return id;
  }

  @override
  /// None once the torrent is removed, as the native session has no
  /// handle for it then.
  List<DownloadEngineFile> getFiles(int torrentId) =>
      removeCalls.any((call) => call.torrentId == torrentId) ? const [] : files;

  @override
  Future<void> initialize() async {}

  @override
  void pause(int torrentId) => pausedTorrentIds.add(torrentId);

  @override
  void remove(int torrentId, {required bool deleteFiles}) {
    removeCalls.add(_RemoveCall(torrentId, deleteFiles: deleteFiles));
    liveTorrentIds.remove(torrentId);
  }

  @override
  void resume(int torrentId) => resumedTorrentIds.add(torrentId);

  @override
  void setFilePriorities(int torrentId, List<int> priorities) {
    priorityCalls.add(_PriorityCall(torrentId, List.of(priorities)));
  }

  @override
  Stream<Map<int, DownloadEngineTorrent>> get torrentUpdates =>
      _controller.stream;

  /// When set, metadata waits block until it completes.
  Completer<void>? metadataGate;

  @override
  Future<void> waitForMetadata(
    int torrentId, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    await metadataGate?.future;
  }

  void emit(Map<int, DownloadEngineTorrent> torrents) {
    _controller.add(torrents);
  }

  Future<void> close() => _controller.close();
}

class _FakeForegroundService implements DownloadForegroundServiceAdapter {
  int startCount = 0;
  int updateCount = 0;
  int stopCount = 0;

  /// When set, start and update calls wait for it.
  Completer<void>? startGate;
  Completer<void>? updateGate;

  @override
  Future<void> start({required String text}) async {
    startCount++;
    await startGate?.future;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> update({required String text}) async {
    updateCount++;
    await updateGate?.future;
  }
}

class _FakeStorageUsageAdapter implements AppStorageUsageAdapter {
  const _FakeStorageUsageAdapter({this.usage = 300});

  final int? usage;

  @override
  Future<int?> totalBytes() async => usage;
}

/// A registry on a full disk: every write fails.
class _RefusingRegistry extends DownloadRegistryDataSource {
  _RefusingRegistry({required super.registryFile});

  int refused = 0;

  @override
  Future<void> writeDownloads(List<DownloadItem> downloads) async {
    refused++;
    throw const FileSystemException('No space left on device');
  }
}

class _CountingRegistry extends DownloadRegistryDataSource {
  _CountingRegistry({required super.registryFile});

  int reads = 0;

  @override
  Future<List<DownloadItem>> readDownloads() {
    reads++;
    return super.readDownloads();
  }
}

class _AddCall {
  const _AddCall({
    required this.id,
    required this.magnet,
    required this.savePath,
    required this.metadataOnly,
  });

  final int id;
  final String magnet;
  final String savePath;
  final bool metadataOnly;
}

class _PriorityCall {
  const _PriorityCall(this.torrentId, this.priorities);

  final int torrentId;
  final List<int> priorities;
}

class _RemoveCall {
  const _RemoveCall(this.torrentId, {required this.deleteFiles});

  final int torrentId;
  final bool deleteFiles;

  @override
  bool operator ==(Object other) {
    return other is _RemoveCall &&
        other.torrentId == torrentId &&
        other.deleteFiles == deleteFiles;
  }

  @override
  int get hashCode => Object.hash(torrentId, deleteFiles);
}

DownloadEngineTorrent _torrent({required bool isFinished, double? progress}) {
  return DownloadEngineTorrent(
    progress: progress ?? (isFinished ? 1 : 0.5),
    downloadRateBytesPerSecond: isFinished ? 0 : 1024,
    peers: 4,
    isFinished: isFinished,
    hasError: false,
    errorMessage: '',
  );
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw TimeoutException('Condition was not met.');
}

extension on DownloadsRepositoryImpl {
  /// Queues [file] and leaves its selection screen, which lets the source
  /// go: the queue then starts what it holds.
  Future<DownloadItem> enqueueAndLeave({
    required PreparedDownloadSource source,
    required DownloadableFile file,
    required String animeId,
    required String animeTitle,
    required String sourceTitle,
    int? quality,
  }) async {
    final item = await enqueueDownload(
      source: source,
      file: file,
      animeId: animeId,
      animeTitle: animeTitle,
      sourceTitle: sourceTitle,
      quality: quality,
    );
    await disposePreparedSource(sourceToken: source.sourceToken);
    return item;
  }
}
