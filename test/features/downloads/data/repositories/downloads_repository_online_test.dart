import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:iris/features/downloads/data/adapters/app_storage_usage_adapter.dart';
import 'package:iris/features/downloads/data/adapters/download_foreground_service_adapter.dart';
import 'package:iris/features/downloads/data/adapters/libtorrent_download_engine_adapter.dart';
import 'package:iris/features/downloads/data/adapters/online_episode_downloader.dart';
import 'package:iris/features/downloads/data/datasources/download_registry_data_source.dart';
import 'package:iris/features/downloads/data/repositories/downloads_repository_impl.dart';
import 'package:iris/features/downloads/domain/entities/download_failure.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/shared/online/online_source_link.dart';
import 'package:iris/shared/torrent/preparation_cancelled_exception.dart';

const _link = 'online:anilibria/9542?anime=52991';

const _episodes = [
  DownloadableFile(index: 1, name: '01', relativePath: '', size: 0),
  DownloadableFile(index: 2, name: '02 «Title»', relativePath: '', size: 0),
];

void main() {
  late Directory temporaryDirectory;
  late Directory downloadsDirectory;
  late _FakeOnlineDownloader online;
  late _FakeForegroundService foregroundService;
  late DownloadsRepositoryImpl repository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'iris_online_downloads_test_',
    );
    downloadsDirectory = Directory(
      path.join(temporaryDirectory.path, 'downloads'),
    );
    online = _FakeOnlineDownloader();
    foregroundService = _FakeForegroundService();
    repository = DownloadsRepositoryImpl(
      engine: _UnusedEngine(),
      registry: DownloadRegistryDataSource(
        registryFile: File(path.join(temporaryDirectory.path, 'registry.json')),
      ),
      downloadsDirectory: downloadsDirectory,
      foregroundService: foregroundService,
      storageUsageAdapter: const _FakeStorageUsageAdapter(),
      onlineDownloader: online,
      now: () => DateTime.utc(2026, 10, 12, 12),
    );
  });

  tearDown(() async {
    await repository.close();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  Future<DownloadItem> enqueueEpisode(int index, {int? quality}) async {
    final source = await repository.prepareSource(magnet: _link);
    return repository.enqueueDownload(
      source: source,
      file: source.files.firstWhere((file) => file.index == index),
      animeId: '52991',
      animeTitle: 'Frieren',
      sourceTitle: 'AniLibria',
      quality: quality,
    );
  }

  Future<DownloadItem> latest(String id) async {
    final downloads = await repository.currentDownloads();
    return downloads.firstWhere((item) => item.id == id);
  }

  test('offers a release\'s episodes to choose from', () async {
    final source = await repository.prepareSource(magnet: _link);

    expect(source.files, _episodes);
    expect(source.qualities, [720, 480]);
    expect(online.listed, [OnlineSourceLink.tryParse(_link)]);
  });

  test('loads an episode in the quality it was queued in, also after a '
      'restart', () async {
    final item = await enqueueEpisode(2, quality: 480);
    await _waitFor(() => online.tasks.isNotEmpty);

    expect(item.quality, 480);
    expect(online.tasks.single.maxQuality, 480);

    await repository.close();
    repository = DownloadsRepositoryImpl(
      engine: _UnusedEngine(),
      registry: DownloadRegistryDataSource(
        registryFile: File(path.join(temporaryDirectory.path, 'registry.json')),
      ),
      downloadsDirectory: downloadsDirectory,
      foregroundService: foregroundService,
      storageUsageAdapter: const _FakeStorageUsageAdapter(),
      onlineDownloader: online,
    );
    await repository.restore();
    await _waitFor(() => online.tasks.length == 2);
    expect(online.tasks.last.maxQuality, 480);
  });

  test('stops waiting for the episode list when the picker goes', () async {
    online.episodeList = Completer<List<DownloadableFile>>();
    final cancelled = Completer<void>();
    final preparing = repository.prepareSource(
      magnet: _link,
      cancelled: cancelled.future,
    );
    cancelled.complete();

    await expectLater(preparing, throwsA(isA<PreparationCancelledException>()));
  });

  test('queues an episode, loads it and keeps the finished file', () async {
    final item = await enqueueEpisode(2);
    await _waitFor(() => foregroundService.calls.isNotEmpty);

    expect(item.isOnline, isTrue);
    expect(item.magnet, _link);
    expect(item.fileName, '02 «Title»');
    final task = online.tasks.single;
    expect(task.fileIndex, 2);
    expect((await latest(item.id)).status, DownloadStatus.downloading);
    expect(foregroundService.calls, ['start 02 «Title»']);

    task.report(
      const OnlineDownloadProgress(
        downloadedBytes: 40,
        totalBytes: 160,
        rateBytesPerSecond: 20,
      ),
    );
    await _eventually(() async => (await latest(item.id)).downloadedBytes > 0);
    final loading = await latest(item.id);
    expect(loading.downloadedBytes, 40);
    expect(loading.totalBytes, 160);
    expect(loading.downloadRateBytesPerSecond, 20);
    expect(loading.peers, 0);

    final video = File(path.join(task.directory.path, 'episode.ts'));
    await video.writeAsString('0123456789');
    task.finish(video);
    await _waitFor(() => foregroundService.calls.last == 'stop');

    final done = await latest(item.id);
    expect(done.status, DownloadStatus.completed);
    expect(done.localPath, video.path);
    expect(done.relativePath, 'episode.ts');
    expect(done.totalBytes, 10);
    expect(done.downloadedBytes, 10);
    expect(await repository.findCompletedById(id: item.id), done);
    expect(foregroundService.calls.last, 'stop');
  });

  test('an episode queued twice is one download', () async {
    final first = await enqueueEpisode(2);
    final second = await enqueueEpisode(2);

    expect(second.id, first.id);
    expect(await repository.currentDownloads(), hasLength(1));
  });

  test('episodes load one after another', () async {
    final first = await enqueueEpisode(1);
    final second = await enqueueEpisode(2);
    await _waitFor(() => foregroundService.calls.isNotEmpty);
    expect(online.tasks, hasLength(1));
    expect((await latest(second.id)).status, DownloadStatus.queued);

    final video = File(path.join(online.tasks.first.directory.path, 'a.ts'));
    await video.writeAsString('a');
    online.tasks.first.finish(video);
    await _waitFor(() => online.tasks.length == 2);

    expect((await latest(first.id)).status, DownloadStatus.completed);
    expect(online.tasks, hasLength(2));
    expect(online.tasks.last.fileIndex, 2);
  });

  test('a failed episode says why and goes on when retried', () async {
    final item = await enqueueEpisode(2);
    await _waitFor(() => online.tasks.isNotEmpty);

    online.tasks.single.fail(
      const OnlineDownloadException(downloadConnectionLostMessage),
    );
    await _waitFor(() => foregroundService.calls.contains('stop'));
    final failed = await latest(item.id);
    expect(failed.status, DownloadStatus.failed);
    expect(failed.failure, DownloadFailure.connectionLost);

    await repository.retry(id: item.id);
    await _waitFor(() => online.tasks.length == 2);
    expect((await latest(item.id)).status, DownloadStatus.downloading);
  });

  test('pause stops the task and resume starts it again', () async {
    final item = await enqueueEpisode(2);
    await _waitFor(() => online.tasks.isNotEmpty);

    await repository.pause(id: item.id);
    expect(online.tasks.single.cancelled, isTrue);
    expect((await latest(item.id)).status, DownloadStatus.paused);

    await repository.resume(id: item.id);
    await _waitFor(() => online.tasks.length == 2);
    expect((await latest(item.id)).status, DownloadStatus.downloading);
  });

  test('delete stops the task before its folder goes', () async {
    final item = await enqueueEpisode(2);
    await _waitFor(() => online.tasks.isNotEmpty);
    final task = online.tasks.single;
    await File(path.join(task.directory.path, 'episode.ts')).writeAsString('x');

    expect(await repository.delete(id: item.id), isTrue);

    expect(task.cancelled, isTrue);
    expect(task.folderExistedOnCancel, isTrue);
    expect(await task.directory.exists(), isFalse);
    expect(await repository.currentDownloads(), isEmpty);
  });

  test('a loading episode waits in the queue again after a restart', () async {
    final item = await enqueueEpisode(2);
    await _waitFor(() => online.tasks.isNotEmpty);
    await repository.close();

    final restarted = DownloadsRepositoryImpl(
      engine: _UnusedEngine(),
      registry: DownloadRegistryDataSource(
        registryFile: File(path.join(temporaryDirectory.path, 'registry.json')),
      ),
      downloadsDirectory: downloadsDirectory,
      foregroundService: foregroundService,
      storageUsageAdapter: const _FakeStorageUsageAdapter(),
      onlineDownloader: online,
    );
    repository = restarted;
    await restarted.restore();
    await _waitFor(() => online.tasks.length == 2);

    expect(online.tasks.last.fileIndex, item.fileIndex);
  });

  test('the download id is a plain folder name, never a session id', () {
    final id = onlineDownloadId(
      const OnlineSourceLink(
        provider: 'yummyAnime',
        releaseId: '10661:AniDUB / субтитры',
      ),
      12,
    );

    expect(id, matches(RegExp(r'^online-yummyAnime-[0-9a-f]+-12$')));
    expect(OnlineSourceLink.tryParse(id), isNull);
    expect(int.tryParse(id), isNull);
  });
}

class _FakeOnlineDownloader implements OnlineEpisodeDownloader {
  final listed = <OnlineSourceLink>[];
  final tasks = <_FakeTask>[];
  Completer<List<DownloadableFile>>? episodeList;
  List<int> qualities = const [720, 480];

  @override
  Future<({List<DownloadableFile> files, List<int> qualities})> episodes(
    OnlineSourceLink link,
  ) async {
    listed.add(link);
    final files = await (episodeList?.future ?? Future.value(_episodes));
    return (files: files, qualities: qualities);
  }

  @override
  OnlineDownloadTask start({
    required OnlineSourceLink link,
    required int fileIndex,
    required Directory directory,
    int? maxQuality,
  }) {
    final task = _FakeTask(
      fileIndex: fileIndex,
      directory: directory,
      maxQuality: maxQuality,
    );
    tasks.add(task);
    return task;
  }
}

class _FakeTask implements OnlineDownloadTask {
  _FakeTask({
    required this.fileIndex,
    required this.directory,
    required this.maxQuality,
  });

  final int fileIndex;
  final Directory directory;
  final int? maxQuality;
  final _progress = StreamController<OnlineDownloadProgress>.broadcast();
  final _done = Completer<File?>();
  bool cancelled = false;
  bool? folderExistedOnCancel;

  void report(OnlineDownloadProgress update) => _progress.add(update);

  void finish(File file) => _done.complete(file);

  void fail(Object error) => _done.completeError(error);

  @override
  Stream<OnlineDownloadProgress> get progress => _progress.stream;

  @override
  Future<File?> get done => _done.future;

  @override
  Future<void> cancel() async {
    cancelled = true;
    folderExistedOnCancel = await directory.exists();
    if (!_done.isCompleted) _done.complete(null);
  }
}

/// Online episodes never reach the torrent engine.
class _UnusedEngine implements LibtorrentDownloadEngineAdapter {
  @override
  Future<void> initialize() async {}

  @override
  Stream<Map<int, DownloadEngineTorrent>> get torrentUpdates =>
      const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('The torrent engine was used: ${invocation.memberName}');
}

class _FakeForegroundService implements DownloadForegroundServiceAdapter {
  final calls = <String>[];

  @override
  Future<void> start({required String text}) async => calls.add('start $text');

  @override
  Future<void> update({required String text}) async =>
      calls.add('update $text');

  @override
  Future<void> stop() async => calls.add('stop');
}

class _FakeStorageUsageAdapter implements AppStorageUsageAdapter {
  const _FakeStorageUsageAdapter();

  @override
  Future<int?> totalBytes() async => null;
}

Future<void> _waitFor(bool Function() condition) =>
    _eventually(() async => condition());

/// The repository writes its registry to disk between steps.
Future<void> _eventually(Future<bool> Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw TimeoutException('Condition was not met.');
}
