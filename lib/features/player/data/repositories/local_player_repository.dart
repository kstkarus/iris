import 'dart:async';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/player/data/adapters/player_runtime_memory_adapter.dart';
import 'package:iris/features/player/domain/downloaded_player_source.dart';
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
    final download = sessionId.startsWith(downloadedSourcePrefix)
        ? await _findSourceDownload(sessionId, fileIndex)
        : await _downloadsRepository.findCompletedById(id: sessionId);
    if (download == null) {
      yield const PlayerLaunchFailureUpdate();
      return;
    }
    yield PlayerLaunchReadyUpdate(
      PlayerSession(sessionId: sessionId, streamUrl: download.localPath),
    );
  }

  Future<DownloadItem?> _findSourceDownload(
    String sessionId,
    int fileIndex,
  ) async {
    final scopeEnd = sessionId.indexOf(':', downloadedSourcePrefix.length);
    if (scopeEnd < 0) return null;
    final scope = sessionId
        .substring(downloadedSourcePrefix.length, scopeEnd)
        .split('/');
    final sourceKey = sessionId.substring(scopeEnd + 1);
    final shared = scope.length == 2 && scope.last == '$fileIndex';
    bool matchesTitle(DownloadItem item) =>
        Uri.encodeComponent(item.animeId) == scope.first;
    bool matchesFile(DownloadItem item) =>
        item.status == DownloadStatus.completed &&
        item.fileIndex == fileIndex &&
        downloadSourceKey(item.magnet) == sourceKey;
    final candidates = (await _downloadsRepository.watchDownloads().first)
        .where(matchesFile);
    final item =
        candidates.where(matchesTitle).firstOrNull ??
        (shared
            ? candidates.where((item) => !item.isOnline).firstOrNull
            : null);
    if (item == null) return null;
    final download = await _downloadsRepository.findCompletedById(id: item.id);
    if (download == null || !matchesFile(download)) return null;
    return matchesTitle(download) || (shared && !download.isOnline)
        ? download
        : null;
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
