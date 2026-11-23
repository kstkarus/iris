import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/player/data/repositories/release_player_repository.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';

import '../../../../helpers/fake_player_repository.dart';
import '../../player_source_test_fixtures.dart';

void main() {
  test(
    'Next can move between local files and one shared streaming session',
    () async {
      final downloads = ReleaseDownloadsFixture(
        files: testReleaseFiles(4),
        downloads: [
          testReleaseDownload(1, DownloadStatus.completed),
          testReleaseDownload(4, DownloadStatus.completed),
        ],
      );
      addTearDown(downloads.closeFixture);
      final player = _StreamingRepository();
      final release = ReleasePlayerRepository(
        magnet: testReleaseLink,
        player: player,
        downloads: downloads,
      );

      Future<PlayerSession> play(int index) async {
        final update = await release
            .startPlayback(sessionId: 'release', fileIndex: index)
            .single;
        return (update as PlayerLaunchReadyUpdate).session;
      }

      expect((await play(1)).streamUrl, 'local/episode-1.mkv');
      expect(player.preparations, 0);
      expect(player.startedFileIndices, isEmpty);

      expect((await play(2)).streamUrl, 'http://example.test/2');
      await release.stopPlayback(sessionId: 'release');
      expect((await play(3)).streamUrl, 'http://example.test/3');
      await release.stopPlayback(sessionId: 'release');
      expect(player.preparations, 1);
      expect(player.stopped, ['remote', 'remote']);

      expect((await play(4)).streamUrl, 'local/episode-4.mkv');
      expect(player.startedFileIndices, [2, 3]);
      expect(player.disposedSessionIds, ['remote']);
      await release.disposePlayback(sessionId: 'download-4');
      expect(player.disposedSessionIds, ['remote']);
    },
  );

  test('a completed item whose file is gone falls back to streaming', () async {
    final downloads = ReleaseDownloadsFixture(
      files: testReleaseFiles(2),
      downloads: [testReleaseDownload(1, DownloadStatus.completed)],
    )..filesMissingOnDisk.add(1);
    addTearDown(downloads.closeFixture);
    final player = _StreamingRepository();
    final release = ReleasePlayerRepository(
      magnet: testReleaseLink,
      player: player,
      downloads: downloads,
    );
    final ready = await release
        .startPlayback(sessionId: 'release', fileIndex: 1)
        .single;
    expect(
      (ready as PlayerLaunchReadyUpdate).session.streamUrl,
      'http://example.test/1',
    );
    await release.disposePlayback(sessionId: ready.session.sessionId);
    expect(player.disposedSessionIds, ['remote']);
  });

  test('cancelling a launch disposes a late streaming session once', () async {
    final downloads = ReleaseDownloadsFixture(files: testReleaseFiles(2));
    addTearDown(downloads.closeFixture);
    final player = _StreamingRepository()
      ..deferred = Completer<PreparedPlayerSource>();
    final release = ReleasePlayerRepository(
      magnet: testReleaseLink,
      player: player,
      downloads: downloads,
    );
    final updates = <PlayerLaunchUpdate>[];
    final launch = release
        .startPlayback(sessionId: 'release', fileIndex: 2)
        .listen(updates.add);
    final cancellation = await player.preparing.future;
    await launch.cancel();
    await cancellation.future;
    await release.disposePlayback(sessionId: 'release');
    player.deferred!.complete(
      const PreparedPlayerSource(sessionId: 'late', files: []),
    );
    await player.disposed.future;
    expect(updates, isEmpty);
    expect(player.startedFileIndices, isEmpty);
    expect(player.disposedSessionIds, ['late']);
  });
}

class _StreamingRepository extends StubPlayerRepository {
  _StreamingRepository()
    : super(
        launches: (index) => Stream.value(
          PlayerLaunchReadyUpdate(
            PlayerSession(
              sessionId: 'remote',
              streamUrl: 'http://example.test/$index',
            ),
          ),
        ),
      );

  int preparations = 0;
  Completer<PreparedPlayerSource>? deferred;
  final preparing = Completer<({Future<void> future})>();
  final disposed = Completer<void>();
  final stopped = <String>[];

  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    preparations++;
    if (!preparing.isCompleted) preparing.complete((future: cancelled!));
    return deferred?.future ??
        const PreparedPlayerSource(sessionId: 'remote', files: []);
  }

  @override
  Future<void> stopPlayback({required String sessionId}) async =>
      stopped.add(sessionId);

  @override
  Future<void> disposePlayback({required String sessionId}) async {
    await super.disposePlayback(sessionId: sessionId);
    if (!disposed.isCompleted) disposed.complete();
  }
}
