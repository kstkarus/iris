import 'dart:async';

import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/player/domain/downloaded_player_source.dart';
import 'package:iris/features/player/data/adapters/player_runtime_memory_adapter.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';

class LocalPlayerRepository implements PlayerRepository {
  const LocalPlayerRepository({
    required DownloadsRepository downloadsRepository,
    required PlayerRuntimeMemoryAdapter memoryAdapter,
  }) : _downloadsRepository = downloadsRepository,
       _memoryAdapter = memoryAdapter;

  final DownloadsRepository _downloadsRepository;
  final PlayerRuntimeMemoryAdapter _memoryAdapter;

  @override
  Future<void> stopPlayback({required String sessionId}) async {}

  @override
  Future<void> disposePlayback({required String sessionId}) async {}

  /// A file on disk does not expire.
  @override
  Future<PlayerSession?> renewSession(PlayerSession session) async => null;

  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) {
    throw UnsupportedError('Completed downloads have no source to prepare.');
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) async* {
    var downloadId = sessionId;
    if (sessionId.startsWith(downloadedSourcePrefix)) {
      final key = sessionId.substring(downloadedSourcePrefix.length);
      final items = await _downloadsRepository.watchDownloads().first;
      final item = items
          .where(
            (item) =>
                downloadSourceKey(item.magnet) == key &&
                item.status == DownloadStatus.completed &&
                item.fileIndex == fileIndex,
          )
          .firstOrNull;
      if (item == null) {
        yield const PlayerLaunchFailureUpdate();
        return;
      }
      downloadId = item.id;
    }
    final download = await _downloadsRepository.findCompletedById(
      id: downloadId,
    );
    if (download == null) {
      yield const PlayerLaunchFailureUpdate();
      return;
    }
    yield PlayerLaunchReadyUpdate(
      PlayerSession(sessionId: sessionId, streamUrl: download.localPath),
    );
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({
    required String sessionId,
  }) async* {
    while (true) {
      final appMemoryBytes = await _memoryAdapter.getAppMemoryBytes();
      yield PlayerPlaybackStats(
        downloadRateBytesPerSecond: 0,
        appMemoryBytes: appMemoryBytes,
        activePeers: 0,
        bufferSeconds: 0,
        bufferPieces: 0,
        readaheadWindow: 0,
      );
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
}
