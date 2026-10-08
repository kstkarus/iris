import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/data/repositories/mock_downloads_repository.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';

void main() {
  test(
    'subscribes again on retry after the stream reported an error',
    () async {
      final failing = StreamController<List<DownloadItem>>();
      final healthy = StreamController<List<DownloadItem>>();
      addTearDown(failing.close);
      addTearDown(healthy.close);
      final repository = _StreamsDownloadsRepository([
        failing.stream,
        healthy.stream,
      ]);
      final cubit = DownloadManagerCubit(repository: repository);

      await cubit.load();
      failing.addError(StateError('registry unavailable'));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.hasError, isTrue);

      await cubit.load();
      healthy.add([_item('download-1')]);
      await Future<void>.delayed(Duration.zero);

      expect(failing.hasListener, isFalse);
      expect(repository.watchCount, 2);
      expect(cubit.state.hasError, isFalse);
      expect(cubit.state.downloads, [_item('download-1')]);
      await cubit.close();
    },
  );

  test('keeps the list updating after an error on the same stream', () async {
    final stream = StreamController<List<DownloadItem>>();
    addTearDown(stream.close);
    final repository = _StreamsDownloadsRepository([stream.stream]);
    final cubit = DownloadManagerCubit(repository: repository);

    await cubit.load();
    stream.add([_item('download-1')]);
    await Future<void>.delayed(Duration.zero);
    stream.addError(StateError('one bad read'));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.hasError, isTrue);
    expect(cubit.state.downloads, [_item('download-1')]);

    stream.add([_item('download-1'), _item('download-2')]);
    await Future<void>.delayed(Duration.zero);

    expect(repository.watchCount, 1);
    expect(cubit.state.hasError, isFalse);
    expect(cubit.state.downloads, [_item('download-1'), _item('download-2')]);
    await cubit.close();
  });

  test('subscribes again on load after the download stream ended', () async {
    final repository = _StreamsDownloadsRepository([
      Stream.value([_item('download-1')]),
      Stream.value([_item('download-1'), _item('download-2')]),
    ]);
    final cubit = DownloadManagerCubit(repository: repository);

    await cubit.load();
    await Future<void>.delayed(Duration.zero);
    await cubit.load();
    await Future<void>.delayed(Duration.zero);

    expect(repository.watchCount, 2);
    expect(cubit.state.downloads, [_item('download-1'), _item('download-2')]);
    await cubit.close();
  });

  test('does not subscribe again while the stream is healthy', () async {
    final stream = StreamController<List<DownloadItem>>();
    addTearDown(stream.close);
    final repository = _StreamsDownloadsRepository([stream.stream]);
    final cubit = DownloadManagerCubit(repository: repository);

    await cubit.load();
    await cubit.load();

    expect(repository.watchCount, 1);
    await cubit.close();
  });

  test(
    'does not subscribe again when closed while cancelling a failed stream',
    () async {
      final cancelling = Completer<void>();
      final failing = StreamController<List<DownloadItem>>(
        onCancel: () => cancelling.future,
      );
      addTearDown(failing.close);
      final repository = _StreamsDownloadsRepository([
        failing.stream,
        Stream.value([_item('download-2')]),
      ]);
      final cubit = DownloadManagerCubit(repository: repository);

      await cubit.load();
      failing.addError(StateError('registry unavailable'));
      await Future<void>.delayed(Duration.zero);

      final retry = cubit.load();
      final closing = cubit.close();
      cancelling.complete();
      await Future.wait([retry, closing]);

      expect(repository.watchCount, 1);
    },
  );
}

/// Hands out one stream per [watchDownloads] call, in order.
class _StreamsDownloadsRepository extends MockDownloadsRepository {
  _StreamsDownloadsRepository(this._streams);

  final List<Stream<List<DownloadItem>>> _streams;
  int watchCount = 0;

  @override
  Stream<List<DownloadItem>> watchDownloads() => _streams[watchCount++];
}

DownloadItem _item(String id) {
  return DownloadItem(
    id: id,
    animeId: '5114',
    animeTitle: 'Fullmetal Alchemist: Brotherhood',
    sourceTitle: '[SubsPlease] Fullmetal Alchemist: Brotherhood - 01',
    magnet: 'magnet:?xt=urn:btih:test-$id',
    fileIndex: 0,
    fileName: 'episode-01.mkv',
    relativePath: 'episode-01.mkv',
    localPath: 'episode-01.mkv',
    totalBytes: 1000,
    downloadedBytes: 1000,
    downloadRateBytesPerSecond: 0,
    peers: 0,
    status: DownloadStatus.completed,
    createdAt: DateTime(2026),
    completedAt: DateTime(2026, 1, 2),
  );
}
