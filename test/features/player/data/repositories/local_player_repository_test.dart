import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/player/data/repositories/local_player_repository.dart';
import 'package:iris/features/player/domain/downloaded_player_source.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';

import '../../player_test_doubles.dart';

void main() {
  test('opens only a completed download as a local media file', () async {
    final repository = LocalPlayerRepository(
      downloadsRepository: _DownloadsRepositoryFake(_completedDownload),
      memoryAdapter: const FixedMemoryAdapter(1024),
    );

    final updates = await repository
        .startPlayback(sessionId: _completedDownload.id, fileIndex: 0)
        .toList();

    expect(updates, hasLength(1));
    final ready = updates.single as PlayerLaunchReadyUpdate;
    expect(ready.session.streamUrl, _completedDownload.localPath);
    expect(ready.session.sessionId, _completedDownload.id);
  });

  test(
    'one offline source opens the selected completed episode and rejects deletion',
    () async {
      final second = _completedDownload.copyWith(
        id: 'second',
        fileIndex: 1,
        fileName: 'episode-02.mkv',
        localPath: 'second.mkv',
      );
      final pending = _completedDownload.copyWith(
        id: 'third',
        fileIndex: 2,
        status: DownloadStatus.queued,
      );
      final downloads = _DownloadsRepositoryFake.many([
        second.copyWith(id: 'paused-copy', status: DownloadStatus.paused),
        second,
        pending,
        second.copyWith(
          id: 'different-release',
          magnet: 'online:anilibria/other',
          fileIndex: 9,
        ),
        _completedDownload.copyWith(fileName: 'episode-01.mkv'),
      ]);
      final source = downloadedPlayerSource(
        downloads.items,
        _completedDownload.magnet,
      )!;
      expect(source.files.map((file) => file.index), [0, 1]);
      final repository = LocalPlayerRepository(
        downloadsRepository: downloads,
        memoryAdapter: const FixedMemoryAdapter(1024),
      );
      final updates = await repository
          .startPlayback(sessionId: source.sessionId, fileIndex: 1)
          .toList();
      expect(
        (updates.single as PlayerLaunchReadyUpdate).session.streamUrl,
        second.localPath,
      );
      downloads.items.remove(second);
      expect(
        await repository
            .startPlayback(sessionId: source.sessionId, fileIndex: 1)
            .toList(),
        const [PlayerLaunchFailureUpdate()],
      );
    },
  );

  test('rejects a missing or unfinished download', () async {
    final repository = LocalPlayerRepository(
      downloadsRepository: _DownloadsRepositoryFake(null),
      memoryAdapter: const FixedMemoryAdapter(1024),
    );

    final updates = await repository
        .startPlayback(sessionId: 'missing', fileIndex: 0)
        .toList();

    expect(updates, const [PlayerLaunchFailureUpdate()]);
  });
}

final _completedDownload = DownloadItem(
  id: 'download-1',
  animeId: '1',
  animeTitle: 'Anime',
  sourceTitle: 'Release',
  magnet: 'magnet:?xt=urn:btih:hash',
  fileIndex: 0,
  fileName: 'episode.mkv',
  relativePath: 'episode.mkv',
  localPath: '${Directory.systemTemp.path}${Platform.pathSeparator}episode.mkv',
  totalBytes: 100,
  downloadedBytes: 100,
  downloadRateBytesPerSecond: 0,
  peers: 0,
  status: DownloadStatus.completed,
  createdAt: DateTime.utc(2026),
  completedAt: DateTime.utc(2026, 1, 2),
);

class _DownloadsRepositoryFake extends Fake implements DownloadsRepository {
  _DownloadsRepositoryFake(DownloadItem? item) : items = [?item];
  _DownloadsRepositoryFake.many(this.items);
  final List<DownloadItem> items;

  @override
  Stream<List<DownloadItem>> watchDownloads() => Stream.value(List.of(items));

  @override
  Future<DownloadItem?> findCompletedById({required String id}) async => items
      .where((item) => item.id == id && item.status == DownloadStatus.completed)
      .firstOrNull;
}
