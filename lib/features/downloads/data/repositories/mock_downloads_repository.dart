import 'dart:async';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_storage_usage.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';

class MockDownloadsRepository implements DownloadsRepository {
  final StreamController<List<DownloadItem>> _controller =
      StreamController<List<DownloadItem>>.broadcast();
  final List<DownloadItem> _items = [];

  @override
  Future<DownloadStorageUsage> calculateStorageUsage() async {
    return const DownloadStorageUsage(
      downloadsBytes: 0,
      cacheBytes: 0,
      totalBytes: 0,
    );
  }

  @override
  Future<bool> clearCache() async => true;

  @override
  Future<List<DownloadItem>> currentDownloads() async => List.of(_items);

  @override
  Future<bool> delete({required String id}) async {
    _items.removeWhere((item) => item.id == id);
    _emit();
    return true;
  }

  @override
  Future<void> disposePreparedSource({required String sourceToken}) async {}

  @override
  Future<DownloadItem> enqueueDownload({
    required PreparedDownloadSource source,
    required DownloadableFile file,
    required String animeId,
    required String animeTitle,
    required String sourceTitle,
  }) async {
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
      downloadedBytes: file.size,
      downloadRateBytesPerSecond: 0,
      peers: 0,
      status: DownloadStatus.completed,
      createdAt: DateTime(2026),
      completedAt: DateTime(2026, 1, 2),
    );
    _items.add(item);
    _emit();
    return item;
  }

  @override
  Future<DownloadItem?> findCompletedById({required String id}) async {
    for (final item in _items) {
      if (item.id == id && item.status == DownloadStatus.completed) return item;
    }
    return null;
  }

  @override
  Future<void> pause({required String id}) =>
      _setStatus(id, DownloadStatus.paused);

  @override
  Future<PreparedDownloadSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    return const PreparedDownloadSource(
      sourceToken: 'mock-source',
      files: [
        DownloadableFile(
          index: 0,
          name: 'episode-01.mkv',
          relativePath: 'episode-01.mkv',
          size: 734003200,
          extension: 'mkv',
        ),
      ],
    );
  }

  @override
  Future<void> restore() async {}

  @override
  Future<void> resume({required String id}) =>
      _setStatus(id, DownloadStatus.queued);

  @override
  Future<void> retry({required String id}) =>
      _setStatus(id, DownloadStatus.queued);

  @override
  Stream<List<DownloadItem>> watchDownloads() async* {
    yield List.of(_items);
    yield* _controller.stream;
  }

  Future<void> _setStatus(String id, DownloadStatus status) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(status: status);
    _emit();
  }

  void _emit() => _controller.add(List.of(_items));
}
