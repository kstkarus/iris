import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/player/data/adapters/player_runtime_memory_adapter.dart';
import 'package:iris/features/player/data/repositories/local_player_repository.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';

void main() {
  test('opens only a completed download as a local media file', () async {
    final repository = LocalPlayerRepository(
      downloadsRepository: _DownloadsRepositoryFake(_completedDownload),
      memoryAdapter: const _MemoryAdapterFake(),
    );

    final updates = await repository
        .startPlayback(sessionId: _completedDownload.id, fileIndex: 0)
        .toList();

    expect(updates, hasLength(1));
    final ready = updates.single as PlayerLaunchReadyUpdate;
    expect(ready.session.streamUrl, _completedDownload.localPath);
    expect(ready.session.sessionId, _completedDownload.id);
  });

  test('rejects a missing or unfinished download', () async {
    final repository = LocalPlayerRepository(
      downloadsRepository: _DownloadsRepositoryFake(null),
      memoryAdapter: const _MemoryAdapterFake(),
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
  _DownloadsRepositoryFake(this.item);

  final DownloadItem? item;

  @override
  Future<DownloadItem?> findCompletedById({required String id}) async => item;
}

class _MemoryAdapterFake implements PlayerRuntimeMemoryAdapter {
  const _MemoryAdapterFake();

  @override
  Future<int?> getAppMemoryBytes() async => 1024;
}
