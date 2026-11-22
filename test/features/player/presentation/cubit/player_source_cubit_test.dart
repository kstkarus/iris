import 'dart:async';
import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/downloads/data/repositories/mock_downloads_repository.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/data/repositories/local_player_repository.dart';
import 'package:iris/features/player/data/repositories/streaming_or_local_player_repository.dart';
import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/no_playable_video_exception.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';

import '../../../../helpers/fake_player_repository.dart';
import '../../player_test_doubles.dart';

void main() {
  test(
    'resume uses only completed files for the selected title in a shared torrent',
    () async {
      final downloads = MockDownloadsRepository();
      for (final (index, animeId) in [(0, '1'), (1, '2'), (2, '')]) {
        await downloads.enqueueDownload(
          source: const PreparedDownloadSource(sourceToken: 's', files: []),
          file: DownloadableFile(
            index: index,
            name: 'episode-$index.mkv',
            relativePath: 'episode-$index.mkv',
            size: 1,
          ),
          animeId: animeId,
          animeTitle: 'Anime',
          sourceTitle: 'Release',
        );
      }
      final remote = _PreparedSourceRepository(
        const PreparedPlayerSource(sessionId: 'remote', files: []),
      );
      final cubit = PlayerSourceCubit(
        magnet: 'mock-magnet',
        animeId: '1',
        repository: remote,
        downloadsRepository: downloads,
        preferDownloads: true,
        preferredFileIndex: 0,
      );
      await cubit.loadSource();
      expect(remote.preparations, 0);
      expect(
        (cubit.state as PlayerSourceReady).preparedSource.files.map(
          (file) => file.index,
        ),
        [0],
      );
      await cubit.close();
      final missing = PlayerSourceCubit(
        magnet: 'mock-magnet',
        animeId: '1',
        repository: remote,
        downloadsRepository: downloads,
        preferDownloads: true,
        preferredFileIndex: 4,
      );
      await missing.loadSource();
      expect(remote.preparations, 1);
      await missing.close();
    },
  );

  test(
    'Continue Watching opens a shared download and keeps Next on the active title',
    () async {
      final downloads = MockDownloadsRepository();
      const magnet = 'mock-magnet';
      for (final (index, animeId) in [(0, '1'), (1, '1'), (2, '2')]) {
        await downloads.enqueueDownload(
          source: const PreparedDownloadSource(sourceToken: 's', files: []),
          file: DownloadableFile(
            index: index,
            name: 'episode-${index + 1}.mkv',
            relativePath: 'episode-${index + 1}.mkv',
            size: 1,
          ),
          animeId: animeId,
          animeTitle: 'Anime $animeId',
          sourceTitle: 'Release',
        );
      }
      final args = AnimePlayerSourceArgs.resume(
        WatchProgress(
          torrentKey: magnet,
          fileIndex: 0,
          fileName: 'episode-1.mkv',
          magnet: magnet,
          sourceTitle: 'Release',
          position: const Duration(minutes: 5),
          duration: const Duration(minutes: 24),
          updatedAt: DateTime.utc(2026),
          animeId: '2',
          animeTitle: 'Anime 2',
        ),
      );
      final streaming = _UnsupportedSourceRepository();
      final repository = StreamingOrLocalPlayerRepository(
        streaming: streaming,
        online: streaming,
        local: LocalPlayerRepository(
          downloadsRepository: downloads,
          memoryAdapter: const FixedMemoryAdapter(0),
        ),
      );
      final cubit = PlayerSourceCubit(
        magnet: args.magnet,
        animeId: args.animeId,
        repository: repository,
        downloadsRepository: downloads,
        preferDownloads: args.preferDownloads,
        preferredFileIndex: args.autoOpenFileIndex,
      );
      addTearDown(cubit.close);
      await cubit.loadSource();

      final prepared = (cubit.state as PlayerSourceReady).preparedSource;
      final source = AnimePlayerSource(
        animeId: args.animeId,
        animeTitle: args.animeTitles.name,
        sourceTitle: args.sourceTitle,
        sessionId: prepared.sessionId,
        fileIndex: args.autoOpenFileIndex!,
        fileName: prepared.files.first.name,
        files: prepared.files,
      );
      expect(source.files.map((file) => file.index), [0, 2]);
      expect(source.nextFile?.index, 2);
      for (final (index, path) in [
        (0, 'episode-1.mkv'),
        (2, 'episode-3.mkv'),
      ]) {
        final updates = await repository
            .startPlayback(sessionId: source.sessionId, fileIndex: index)
            .toList();
        expect(
          (updates.single as PlayerLaunchReadyUpdate).session.streamUrl,
          path,
        );
      }
      expect(
        await repository
            .startPlayback(sessionId: source.sessionId, fileIndex: 1)
            .single,
        const PlayerLaunchFailureUpdate(),
      );
    },
  );

  test('emits loading then success when source files are prepared', () async {
    final cubit = PlayerSourceCubit(
      magnet: 'magnet:?xt=urn:btih:test-source',
      repository: _PreparedSourceRepository(
        const PreparedPlayerSource(
          sessionId: '42',
          files: [
            PlayerVideoFile(
              index: 1,
              name: 'episode-01.mkv',
              size: 700,
              extension: 'mkv',
            ),
            PlayerVideoFile(
              index: 2,
              name: 'episode-02.mkv',
              size: 800,
              extension: 'mkv',
            ),
          ],
        ),
      ),
    );

    expectLater(
      cubit.stream,
      emitsInOrder([
        const PlayerSourceLoading(),
        const PlayerSourceReady(
          PreparedPlayerSource(
            sessionId: '42',
            files: [
              PlayerVideoFile(
                index: 1,
                name: 'episode-01.mkv',
                size: 700,
                extension: 'mkv',
              ),
              PlayerVideoFile(
                index: 2,
                name: 'episode-02.mkv',
                size: 800,
                extension: 'mkv',
              ),
            ],
          ),
        ),
      ]),
    );

    await cubit.loadSource();
  });

  test(
    'emits unsupported-source failure when repository finds no video files',
    () async {
      final cubit = PlayerSourceCubit(
        magnet: 'magnet:?xt=urn:btih:test-source',
        repository: _UnsupportedSourceRepository(),
      );

      expectLater(
        cubit.stream,
        emitsInOrder([
          const PlayerSourceLoading(),
          const PlayerSourceFailure(PlayerSourceFailureType.unsupportedSource),
        ]),
      );

      await cubit.loadSource();
    },
  );

  test(
    'disposes prepared source on close when ownership was not transferred',
    () async {
      final repository = _PreparedSourceRepository(
        const PreparedPlayerSource(
          sessionId: '42',
          files: [
            PlayerVideoFile(
              index: 1,
              name: 'episode-01.mkv',
              size: 700,
              extension: 'mkv',
            ),
          ],
        ),
      );
      final cubit = PlayerSourceCubit(
        magnet: 'magnet:?xt=urn:btih:test-source',
        repository: repository,
      );

      await cubit.loadSource();
      await cubit.close();

      expect(repository.disposedSessionIds, ['42']);
    },
  );

  test('does not dispose prepared source after ownership transfer', () async {
    final repository = _PreparedSourceRepository(
      const PreparedPlayerSource(
        sessionId: '42',
        files: [
          PlayerVideoFile(
            index: 1,
            name: 'episode-01.mkv',
            size: 700,
            extension: 'mkv',
          ),
        ],
      ),
    );
    final cubit = PlayerSourceCubit(
      magnet: 'magnet:?xt=urn:btih:test-source',
      repository: repository,
    );

    await cubit.loadSource();
    cubit.transferSessionOwnership();
    await cubit.close();

    expect(repository.disposedSessionIds, isEmpty);
  });

  test('disposes prepared source after reclaimed ownership on close', () async {
    final repository = _PreparedSourceRepository(
      const PreparedPlayerSource(
        sessionId: '42',
        files: [
          PlayerVideoFile(
            index: 1,
            name: 'episode-01.mkv',
            size: 700,
            extension: 'mkv',
          ),
        ],
      ),
    );
    final cubit = PlayerSourceCubit(
      magnet: 'magnet:?xt=urn:btih:test-source',
      repository: repository,
    );

    await cubit.loadSource();
    cubit.transferSessionOwnership();
    cubit.reclaimSessionOwnership();
    await cubit.close();

    expect(repository.disposedSessionIds, ['42']);
  });

  test(
    'does not emit after close and disposes a late prepared source',
    () async {
      final repository = _DeferredSourceRepository();
      final cubit = PlayerSourceCubit(
        magnet: 'magnet:?xt=urn:btih:test-source',
        repository: repository,
      );

      final loadFuture = cubit.loadSource();
      await cubit.close();

      repository.completeWith(
        const PreparedPlayerSource(
          sessionId: '42',
          files: [
            PlayerVideoFile(
              index: 1,
              name: 'episode-01.mkv',
              size: 700,
              extension: 'mkv',
            ),
          ],
        ),
      );

      await expectLater(loadFuture, completes);
      expect(repository.disposedSessionIds, ['42']);
    },
  );

  test(
    'does not emit after close when source preparation fails late',
    () async {
      final repository = _DeferredSourceRepository();
      final cubit = PlayerSourceCubit(
        magnet: 'magnet:?xt=urn:btih:test-source',
        repository: repository,
      );

      final loadFuture = cubit.loadSource();
      await cubit.close();

      repository.completeWithError(Exception('late failure'));

      await expectLater(loadFuture, completes);
      expect(repository.disposedSessionIds, isEmpty);
    },
  );

  test('closing during a preparation cancels it', () async {
    final repository = _DeferredSourceRepository();
    final cubit = PlayerSourceCubit(
      magnet: 'magnet:?xt=urn:btih:test-source',
      repository: repository,
    );

    unawaited(cubit.loadSource());
    var isCancelled = false;
    unawaited(repository.cancellations.single!.then((_) => isCancelled = true));

    await cubit.close();
    await Future<void>.delayed(Duration.zero);

    expect(isCancelled, isTrue);
  });

  test('loading again cancels the preparation it replaces', () async {
    final repository = _DeferredSourceRepository();
    final cubit = PlayerSourceCubit(
      magnet: 'magnet:?xt=urn:btih:test-source',
      repository: repository,
    );

    unawaited(cubit.loadSource());
    var firstCancelled = false;
    unawaited(
      repository.cancellations.single!.then((_) => firstCancelled = true),
    );

    unawaited(cubit.loadSource());
    await Future<void>.delayed(Duration.zero);

    expect(firstCancelled, isTrue);
    expect(repository.cancellations, hasLength(2));
    await cubit.close();
  });
}

class _PreparedSourceRepository extends StubPlayerRepository {
  _PreparedSourceRepository(this.preparedSource);

  final PreparedPlayerSource preparedSource;
  int preparations = 0;

  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    preparations++;
    return preparedSource;
  }
}

class _UnsupportedSourceRepository extends StubPlayerRepository {
  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    throw const NoPlayableVideoException();
  }
}

class _DeferredSourceRepository extends StubPlayerRepository {
  final Completer<PreparedPlayerSource> _prepareCompleter =
      Completer<PreparedPlayerSource>();
  final List<Future<void>?> cancellations = [];

  void completeWith(PreparedPlayerSource preparedSource) {
    if (!_prepareCompleter.isCompleted) {
      _prepareCompleter.complete(preparedSource);
    }
  }

  void completeWithError(Object error) {
    if (!_prepareCompleter.isCompleted) {
      _prepareCompleter.completeError(error);
    }
  }

  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) {
    cancellations.add(cancelled);
    return _prepareCompleter.future;
  }
}
