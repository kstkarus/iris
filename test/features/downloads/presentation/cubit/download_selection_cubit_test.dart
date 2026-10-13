import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/data/repositories/mock_downloads_repository.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_state.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';

import '../../../../helpers/memory_online_quality_preferences.dart';

const _args = DownloadSelectionArgs(
  animeId: '154587',
  animeTitle: 'Sousou no Frieren',
  sourceTitle: 'Release',
  magnet: 'magnet:?xt=urn:btih:test-selection',
);

void main() {
  test('closing during a preparation cancels it', () async {
    final repository = _DeferredPrepareRepository();
    final cubit = DownloadSelectionCubit(args: _args, repository: repository);

    unawaited(cubit.load());
    var isCancelled = false;
    unawaited(repository.cancellations.single!.then((_) => isCancelled = true));

    await cubit.close();
    await Future<void>.delayed(Duration.zero);

    expect(isCancelled, isTrue);
  });

  test('loading again cancels the preparation it replaces', () async {
    final repository = _DeferredPrepareRepository();
    final cubit = DownloadSelectionCubit(args: _args, repository: repository);

    unawaited(cubit.load());
    var firstCancelled = false;
    unawaited(
      repository.cancellations.single!.then((_) => firstCancelled = true),
    );

    unawaited(cubit.load());
    await Future<void>.delayed(Duration.zero);

    expect(firstCancelled, isTrue);
    expect(repository.cancellations, hasLength(2));
    await cubit.close();
  });

  group('picking files', () {
    late _PickingRepository repository;
    late DownloadSelectionCubit cubit;

    setUp(() async {
      repository = _PickingRepository();
      cubit = DownloadSelectionCubit(args: _args, repository: repository);
      await cubit.load();
    });

    tearDown(() => cubit.close());

    DownloadSelectionReady ready() => cubit.state as DownloadSelectionReady;

    test(
      'several files are queued one tap each, and the screen stays',
      () async {
        await cubit.download(_files[0]);
        await cubit.download(_files[1]);
        await pumpEventQueue();

        expect(repository.queued, [0, 1]);
        expect(ready().downloads.keys, unorderedEquals([0, 1]));
        expect(ready().adding, isEmpty);
      },
    );

    test('a file on its way to the queue is not queued twice', () async {
      repository.gate = Completer<void>();
      final first = cubit.download(_files[0]);
      expect(ready().adding, {0});
      await cubit.download(_files[0]);
      repository.gate!.complete();
      await first;

      expect(repository.queued, [0]);
    });

    test('a queued, loading or done file is left as it is; a paused one '
        'resumes and a failed one is tried again', () async {
      await cubit.download(_files[0]);
      await pumpEventQueue();
      for (final status in [
        DownloadStatus.queued,
        DownloadStatus.downloading,
        DownloadStatus.completed,
      ]) {
        repository.setStatus(0, status);
        await pumpEventQueue();
        await cubit.download(_files[0]);
      }
      expect(repository.queued, [0]);
      expect(repository.resumed, isEmpty);
      expect(repository.retried, isEmpty);

      repository.setStatus(0, DownloadStatus.paused);
      await pumpEventQueue();
      await cubit.download(_files[0]);
      expect(repository.resumed, ['mock-0']);

      repository.setStatus(0, DownloadStatus.failed);
      await pumpEventQueue();
      await cubit.download(_files[0]);
      expect(repository.retried, ['mock-0']);
      expect(repository.queued, [0]);
    });

    test('a file the queue refuses says so until it is tried again', () async {
      repository.refuse = true;
      await cubit.download(_files[1]);
      expect(ready().notAdded, {1});
      expect(ready().adding, isEmpty);

      repository.refuse = false;
      await cubit.download(_files[1]);
      expect(ready().notAdded, isEmpty);
      expect(repository.queued, [1]);
    });

    test('leaving lets the source go once, after files were queued', () async {
      await cubit.download(_files[0]);
      await cubit.download(_files[1]);

      await cubit.close();

      expect(repository.disposed, ['picked']);
    });
  });

  group('an online release', () {
    const online = DownloadSelectionArgs(
      animeId: '52991',
      animeTitle: 'Frieren',
      sourceTitle: 'AniLibria',
      magnet: 'online:anilibria/9542?anime=52991',
    );

    Future<DownloadSelectionCubit> loaded(
      _QualityRepository repository,
      MemoryOnlineQualityPreferences preferences,
    ) async {
      final cubit = DownloadSelectionCubit(
        args: online,
        repository: repository,
        qualityPreferences: preferences,
      );
      addTearDown(cubit.close);
      await cubit.load();
      return cubit;
    }

    test('starts at the quality last chosen for downloads', () async {
      final cubit = await loaded(
        _QualityRepository(),
        MemoryOnlineQualityPreferences(downloading: 720, watching: 1080),
      );

      expect((cubit.state as DownloadSelectionReady).quality, 720);
    });

    test('starts at the closest quality the release has', () async {
      final cubit = await loaded(
        _QualityRepository(),
        MemoryOnlineQualityPreferences(downloading: 600),
      );

      expect((cubit.state as DownloadSelectionReady).quality, 480);
    });

    test('starts at Auto with no choice made yet', () async {
      final cubit = await loaded(
        _QualityRepository(),
        MemoryOnlineQualityPreferences(),
      );

      expect((cubit.state as DownloadSelectionReady).quality, isNull);
    });

    test('remembers a chosen quality and queues the episode in it', () async {
      final repository = _QualityRepository();
      final preferences = MemoryOnlineQualityPreferences(watching: 1080);
      final cubit = await loaded(repository, preferences);

      cubit.chooseQuality(480);
      await cubit.download(_episode);

      expect(preferences.downloading, 480);
      expect(preferences.watching, 1080, reason: 'watching keeps its own');
      expect(repository.queuedQualities, [480]);
    });
  });
}

const _episode = DownloadableFile(
  index: 1,
  name: '01',
  relativePath: '',
  size: 0,
);

class _QualityRepository extends MockDownloadsRepository {
  final queuedQualities = <int?>[];

  @override
  Future<PreparedDownloadSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    return const PreparedDownloadSource(
      sourceToken: 'online',
      files: [_episode],
      qualities: [1080, 720, 480],
    );
  }

  @override
  Future<DownloadItem> enqueueDownload({
    required PreparedDownloadSource source,
    required DownloadableFile file,
    required String animeId,
    required String animeTitle,
    required String sourceTitle,
    int? quality,
  }) {
    queuedQualities.add(quality);
    return super.enqueueDownload(
      source: source,
      file: file,
      animeId: animeId,
      animeTitle: animeTitle,
      sourceTitle: sourceTitle,
      quality: quality,
    );
  }
}

class _DeferredPrepareRepository extends MockDownloadsRepository {
  final List<Future<void>?> cancellations = [];

  @override
  Future<PreparedDownloadSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) {
    cancellations.add(cancelled);
    return Completer<PreparedDownloadSource>().future;
  }
}

const _files = [
  DownloadableFile(
    index: 0,
    name: 'episode-01.mkv',
    relativePath: 'episode-01.mkv',
    size: 100,
  ),
  DownloadableFile(
    index: 1,
    name: 'episode-02.mkv',
    relativePath: 'episode-02.mkv',
    size: 100,
  ),
];

/// A picker's source of two files; its downloads are what a test sets.
class _PickingRepository extends MockDownloadsRepository {
  final queued = <int>[];
  final resumed = <String>[];
  final retried = <String>[];
  final disposed = <String>[];
  Completer<void>? gate;
  bool refuse = false;

  final _downloads = <int, DownloadItem>{};
  final _changes = StreamController<Map<int, DownloadItem>>.broadcast();

  @override
  Future<PreparedDownloadSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    return const PreparedDownloadSource(sourceToken: 'picked', files: _files);
  }

  @override
  Future<void> disposePreparedSource({required String sourceToken}) async {
    disposed.add(sourceToken);
  }

  @override
  Stream<Map<int, DownloadItem>> watchSourceDownloads({
    required String magnet,
  }) async* {
    yield Map.of(_downloads);
    yield* _changes.stream;
  }

  @override
  Future<DownloadItem> enqueueDownload({
    required PreparedDownloadSource source,
    required DownloadableFile file,
    required String animeId,
    required String animeTitle,
    required String sourceTitle,
    int? quality,
  }) async {
    await gate?.future;
    if (refuse) throw StateError('refused');
    queued.add(file.index);
    final item = DownloadItem(
      id: 'mock-${file.index}',
      animeId: animeId,
      animeTitle: animeTitle,
      sourceTitle: sourceTitle,
      magnet: 'mock-magnet',
      fileIndex: file.index,
      fileName: file.name,
      relativePath: file.relativePath,
      localPath: file.relativePath,
      totalBytes: file.size,
      downloadedBytes: 0,
      downloadRateBytesPerSecond: 0,
      peers: 0,
      status: DownloadStatus.queued,
      createdAt: DateTime(2026),
    );
    _set(item);
    return item;
  }

  @override
  Future<void> resume({required String id}) async => resumed.add(id);

  @override
  Future<void> retry({required String id}) async => retried.add(id);

  void setStatus(int index, DownloadStatus status) =>
      _set(_downloads[index]!.copyWith(status: status));

  void _set(DownloadItem item) {
    _downloads[item.fileIndex] = item;
    _changes.add(Map.of(_downloads));
  }
}
