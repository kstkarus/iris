import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_storage_usage.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/downloads/presentation/cubit/download_activity_cubit.dart';

DownloadItem _item(String id, DownloadStatus status, {int downloaded = 0}) =>
    DownloadItem(
      id: id,
      animeId: '1',
      animeTitle: 'Frieren',
      sourceTitle: 'Subs',
      magnet: 'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
      fileIndex: 0,
      fileName: '01.mkv',
      relativePath: '01.mkv',
      localPath: '/tmp/01.mkv',
      totalBytes: 1000,
      downloadedBytes: downloaded,
      downloadRateBytesPerSecond: 100,
      peers: 1,
      status: status,
      createdAt: DateTime(2026),
    );

class _FakeDownloadsRepository implements DownloadsRepository {
  final _controller = StreamController<List<DownloadItem>>.broadcast();

  void emit(List<DownloadItem> items) => _controller.add(items);

  void emitError(Object error) => _controller.addError(error);

  Future<void> dispose() => _controller.close();

  @override
  Stream<List<DownloadItem>> watchDownloads() => _controller.stream;

  @override
  Future<DownloadStorageUsage> calculateStorageUsage() =>
      throw UnimplementedError();

  @override
  Future<bool> clearCache() => throw UnimplementedError();

  @override
  Future<bool> delete({required String id}) => throw UnimplementedError();

  @override
  Future<Set<String>> deleteMany({required Iterable<String> ids}) =>
      throw UnimplementedError();

  @override
  Future<void> disposePreparedSource({required String sourceToken}) =>
      throw UnimplementedError();

  @override
  Future<void> downloadNext({required String id}) => throw UnimplementedError();

  @override
  Future<DownloadItem> enqueueDownload({
    required PreparedDownloadSource source,
    required DownloadableFile file,
    required String animeId,
    required String animeTitle,
    required String sourceTitle,
    String animeRussian = '',
    String animeEnglish = '',
    String posterUrl = '',
    int? quality,
  }) => throw UnimplementedError();

  @override
  Future<DownloadItem?> findCompletedById({required String id}) =>
      throw UnimplementedError();

  @override
  Future<void> pause({required String id}) => throw UnimplementedError();

  @override
  Future<PreparedDownloadSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) => throw UnimplementedError();

  @override
  Future<void> reorderQueue({required List<String> ids}) =>
      throw UnimplementedError();

  @override
  Future<void> resume({required String id}) => throw UnimplementedError();

  @override
  Future<void> retry({required String id}) => throw UnimplementedError();

  @override
  Stream<Map<int, DownloadItem>> watchSourceDownloads({
    required String magnet,
  }) => const Stream.empty();
}

void main() {
  test(
    'emits only on active/idle transitions for downloading or queued items',
    () async {
      final repository = _FakeDownloadsRepository();
      final cubit = DownloadActivityCubit(repository: repository);
      addTearDown(() async {
        await cubit.close();
        await repository.dispose();
      });

      final emitted = <bool>[];
      final sub = cubit.stream.listen(emitted.add);
      addTearDown(sub.cancel);

      repository.emit([_item('a', DownloadStatus.downloading, downloaded: 10)]);
      repository.emit([
        _item('a', DownloadStatus.downloading, downloaded: 200),
      ]);
      repository.emit([_item('a', DownloadStatus.queued)]);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, isTrue);
      expect(emitted, [true]);

      repository.emit([
        _item('a', DownloadStatus.paused),
        _item('b', DownloadStatus.failed),
        _item('c', DownloadStatus.completed),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, isFalse);
      expect(emitted, [true, false]);
    },
  );

  test('falls back to idle on stream error', () async {
    final repository = _FakeDownloadsRepository();
    final cubit = DownloadActivityCubit(repository: repository);
    addTearDown(() async {
      await cubit.close();
      await repository.dispose();
    });

    repository.emit([_item('a', DownloadStatus.downloading)]);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isTrue);

    repository.emitError(StateError('engine down'));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isFalse);
  });
}
