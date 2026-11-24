import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/player/data/repositories/local_player_repository.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';

import '../../../../helpers/fake_player_repository.dart';
import '../../../../helpers/memory_online_quality_preferences.dart';
import '../../player_source_test_fixtures.dart';
import '../../player_test_doubles.dart';

void main() {
  test('one downloaded episode keeps all 28 in the release', () async {
    final downloads = ReleaseDownloadsFixture(
      files: testReleaseFiles(28, named: true),
      downloads: [testReleaseDownload(1, DownloadStatus.completed)],
    );
    final cubit = PlayerSourceCubit(
      args: testReleaseArgs(online: true, preferDownloads: true),
      downloadsRepository: downloads,
      playerRepository: StubPlayerRepository(),
    );
    await cubit.loadSource();

    final ready = cubit.state as PlayerSourceReady;
    expect(
      ready.files.map((file) => file.index),
      List.generate(28, (i) => i + 1),
    );
    expect(ready.files.first.title, 'Story of episode 1');
    expect(ready.files.first.duration, const Duration(minutes: 24));
    expect(ready.downloadFor(1)?.status, DownloadStatus.completed);
    expect(ready.localSessionId, isNull);
    expect(downloads.preparations, 1);
    await cubit.close();
    expect(downloads.disposed, ['release']);
    await downloads.closeFixture();
  });

  test(
    'explicit resume can play a shared local copy and keep Next on the active title',
    () async {
      final downloads = ReleaseDownloadsFixture(
        files: testReleaseFiles(28),
        downloads: [
          for (final (index, animeId) in [
            (1, 'other'),
            (2, 'other'),
            (3, '52991'),
          ])
            testReleaseDownload(
              index,
              DownloadStatus.completed,
              animeId: animeId,
              magnet: testReleaseMagnet,
            ),
        ],
      );
      final cubit = PlayerSourceCubit(
        args: testReleaseArgs(preferDownloads: true, autoOpenFileIndex: 1),
        downloadsRepository: downloads,
        playerRepository: StubPlayerRepository(),
      );
      await cubit.loadSource();

      final ready = cubit.state as PlayerSourceReady;
      expect(ready.files.map((file) => file.index), [1, 3]);
      expect(downloads.preparations, 0);
      final repository = LocalPlayerRepository(
        downloadsRepository: downloads,
        memoryAdapter: const FixedMemoryAdapter(0),
      );
      for (final index in [1, 3]) {
        final update =
            await repository
                    .startPlayback(
                      sessionId: ready.localSessionId!,
                      fileIndex: index,
                    )
                    .single
                as PlayerLaunchReadyUpdate;
        expect(update.session.streamUrl, 'local/episode-$index.mkv');
      }
      await cubit.close();
      expect(downloads.disposed, isEmpty);
      await downloads.closeFixture();
    },
  );

  test(
    'explicit resume with a missing local file prepares the full release',
    () async {
      final downloads = ReleaseDownloadsFixture(
        files: testReleaseFiles(4),
        downloads: [testReleaseDownload(1, DownloadStatus.completed)],
      )..filesMissingOnDisk.add(1);
      final cubit = PlayerSourceCubit(
        args: testReleaseArgs(
          online: true,
          preferDownloads: true,
          autoOpenFileIndex: 1,
        ),
        downloadsRepository: downloads,
        playerRepository: StubPlayerRepository(),
      );
      await cubit.loadSource();
      final ready = cubit.state as PlayerSourceReady;
      expect(ready.localSessionId, isNull);
      expect(ready.files, hasLength(4));
      await cubit.close();
      await downloads.closeFixture();
    },
  );

  test(
    'closing cancels preparation and releases a token returned late',
    () async {
      final downloads = _DelayedDownloads();
      final cubit = PlayerSourceCubit(
        args: testReleaseArgs(),
        downloadsRepository: downloads,
        playerRepository: StubPlayerRepository(),
      );
      final load = cubit.loadSource();
      await cubit.close();
      await downloads.cancellations.single;
      downloads.results.single.complete(
        const PreparedDownloadSource(sourceToken: 'late', files: []),
      );
      await load;
      expect(downloads.disposed, ['late']);
      await downloads.closeFixture();
    },
  );

  test(
    'retry cancels the old preparation and keeps only the new token',
    () async {
      final downloads = _DelayedDownloads();
      final cubit = PlayerSourceCubit(
        args: testReleaseArgs(),
        downloadsRepository: downloads,
        playerRepository: StubPlayerRepository(),
      );
      final old = cubit.loadSource();
      final retry = cubit.loadSource();
      await downloads.cancellations.first;
      downloads.results.last.complete(
        PreparedDownloadSource(sourceToken: 'new', files: testReleaseFiles(2)),
      );
      await retry;
      downloads.results.first.complete(
        const PreparedDownloadSource(sourceToken: 'stale', files: []),
      );
      await old;
      expect((cubit.state as PlayerSourceReady).files, hasLength(2));
      expect(downloads.disposed, ['stale']);
      await cubit.close();
      expect(downloads.disposed, ['stale', 'new']);
      await downloads.closeFixture();
    },
  );

  test(
    'only new files are queued, and a partial failure stays selected',
    () async {
      final downloads = ReleaseDownloadsFixture(
        files: testReleaseFiles(7),
        downloads: [
          for (final (index, status) in DownloadStatus.values.indexed)
            testReleaseDownload(index + 1, status),
        ],
        qualities: [1080, 720],
      )..reject.add(6);
      final preferences = MemoryOnlineQualityPreferences(downloading: 800);
      final cubit = PlayerSourceCubit(
        args: testReleaseArgs(online: true, selectDownloads: true),
        downloadsRepository: downloads,
        playerRepository: StubPlayerRepository(),
        qualityPreferences: preferences,
      );
      await cubit.loadSource();
      PlayerSourceReady ready() => cubit.state as PlayerSourceReady;
      expect(ready().quality, 720);
      cubit.chooseQuality(1080);
      expect(preferences.downloading, 1080);
      cubit.replaceSelection({7, 1, 2, 3, 4, 5, 6, 999});
      expect(ready().selected, {6, 7});
      expect(await cubit.enqueue(), isFalse);
      expect(downloads.enqueued, [
        (index: 7, quality: 1080, posterUrl: testReleasePoster),
      ]);
      expect(downloads.inventoryActions, 0);
      expect(ready().selecting, isTrue);
      expect(ready().selected, {6});

      downloads.reject.clear();
      expect(await cubit.enqueue(), isTrue);
      expect(downloads.enqueued.map((request) => request.index), [7, 6]);
      expect(ready().selecting, isFalse);
      expect(ready().downloadFor(6)?.status, DownloadStatus.queued);
      await cubit.close();
      await downloads.closeFixture();
    },
  );

  test(
    'range selection adds downloadable files between anchor and target and resets on cancel',
    () async {
      final downloads = ReleaseDownloadsFixture(
        files: testReleaseFiles(6),
        downloads: [testReleaseDownload(3, DownloadStatus.completed)],
      );
      final cubit = PlayerSourceCubit(
        args: testReleaseArgs(online: true),
        downloadsRepository: downloads,
        playerRepository: StubPlayerRepository(),
      );
      await cubit.loadSource();
      PlayerSourceReady ready() => cubit.state as PlayerSourceReady;

      cubit.startSelection(index: 2);
      expect(ready().selected, {2});
      cubit.toggleSelection(5, range: true);
      expect(ready().selected, {2, 4, 5});

      cubit.cancelSelection();
      cubit.startSelection();
      cubit.toggleSelection(4, range: true);
      expect(ready().selected, {4});
      cubit.toggleSelection(1, range: true);
      expect(ready().selected, {1, 2, 4});

      await cubit.close();
      await downloads.closeFixture();
    },
  );

  for (final single in [false, true]) {
    test(
      'close lets a pending ${single ? 'single enqueue' : 'batch'} finish before releasing its token',
      () async {
        final gate = Completer<void>();
        final downloads = ReleaseDownloadsFixture(
          files: testReleaseFiles(single ? 1 : 3),
        )..enqueueGate = gate.future;
        final cubit = PlayerSourceCubit(
          args: testReleaseArgs(selectDownloads: !single),
          downloadsRepository: downloads,
          playerRepository: StubPlayerRepository(),
        );
        await cubit.loadSource();
        if (!single) cubit.replaceSelection({3, 2, 1});
        final enqueue = cubit.enqueue(singleIndex: single ? 1 : null);
        final close = cubit.close();
        expect(downloads.disposed, isEmpty);
        gate.complete();
        expect(await enqueue, isTrue);
        await close;
        expect(
          downloads.enqueued.map((request) => request.index),
          single ? [1] : [1, 2, 3],
        );
        expect(downloads.disposed, ['release']);
        await downloads.closeFixture();
      },
    );
  }
}

class _DelayedDownloads extends ReleaseDownloadsFixture {
  _DelayedDownloads() : super(files: []);

  final cancellations = <Future<void>>[];
  final results = <Completer<PreparedDownloadSource>>[];

  @override
  Future<PreparedDownloadSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) {
    cancellations.add(cancelled!);
    final result = Completer<PreparedDownloadSource>();
    results.add(result);
    return result.future;
  }
}
