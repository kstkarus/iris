import 'dart:async';
import 'dart:developer' as developer;

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';

/// One player's release. Opens a streaming session only when a file needs it.
class ReleasePlayerRepository implements PlayerRepository {
  ReleasePlayerRepository({
    required String magnet,
    required PlayerRepository player,
    required DownloadsRepository downloads,
  }) : _magnet = magnet,
       _player = player,
       _downloads = downloads;

  final String _magnet;
  final PlayerRepository _player;
  final DownloadsRepository _downloads;
  String? _streamingSessionId;

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) {
    final cancelled = Completer<void>();
    StreamSubscription<PlayerLaunchUpdate>? stream;
    late final StreamController<PlayerLaunchUpdate> updates;

    Future<void> launch() async {
      try {
        final local = await _completedFile(fileIndex);
        if (cancelled.isCompleted) return;
        if (local != null) {
          // A local episode frees the torrent so its other downloads can run.
          await disposePlayback(sessionId: sessionId);
          if (cancelled.isCompleted) return;
          updates.add(
            PlayerLaunchReadyUpdate(
              PlayerSession(sessionId: local.id, streamUrl: local.localPath),
            ),
          );
          unawaited(updates.close());
          return;
        }

        var streamingId = _streamingSessionId;
        if (streamingId == null) {
          final prepared = await _player.prepareSource(
            magnet: _magnet,
            cancelled: cancelled.future,
          );
          if (cancelled.isCompleted) {
            await _player.disposePlayback(sessionId: prepared.sessionId);
            return;
          }
          _streamingSessionId = streamingId = prepared.sessionId;
        }
        stream = _player
            .startPlayback(sessionId: streamingId, fileIndex: fileIndex)
            .listen(
              updates.add,
              onError: updates.addError,
              onDone: () => unawaited(updates.close()),
            );
      } on Object catch (error, stackTrace) {
        if (cancelled.isCompleted) return;
        updates.addError(error, stackTrace);
        unawaited(updates.close());
      }
    }

    updates = StreamController<PlayerLaunchUpdate>(
      onListen: () => unawaited(launch()),
      onCancel: () async {
        cancelled.complete();
        await stream?.cancel();
      },
    );
    return updates.stream;
  }

  Future<DownloadItem?> _completedFile(int index) async {
    try {
      final items = await _downloads
          .watchSourceDownloads(magnet: _magnet)
          .first;
      final item = items[index];
      if (item?.status != DownloadStatus.completed) return null;
      return await _downloads.findCompletedById(id: item!.id);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Unable to check for a completed local copy.',
        name: 'iris.player.release',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<void> stopPlayback({required String sessionId}) async {
    final streamingId = _streamingSessionId;
    if (streamingId != null) {
      await _player.stopPlayback(sessionId: streamingId);
    }
  }

  @override
  Future<void> disposePlayback({required String sessionId}) async {
    final streamingId = _streamingSessionId;
    _streamingSessionId = null;
    if (streamingId != null) {
      await _player.disposePlayback(sessionId: streamingId);
    }
  }

  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) => _player.prepareSource(magnet: magnet, cancelled: cancelled);

  @override
  Future<PlayerSession?> renewSession(PlayerSession session) =>
      _player.renewSession(session);

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) =>
      _player.watchPlaybackStats(sessionId: sessionId);
}
