import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/no_playable_video_exception.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';

void main() {
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

class _PreparedSourceRepository implements PlayerRepository {
  @override
  Future<void> stopPlayback({required String sessionId}) async {}

  _PreparedSourceRepository(this.preparedSource);

  final PreparedPlayerSource preparedSource;
  final List<String> disposedSessionIds = [];

  @override
  Future<void> disposePlayback({required String sessionId}) async {
    disposedSessionIds.add(sessionId);
  }

  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    return preparedSource;
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return const Stream.empty();
  }
}

class _UnsupportedSourceRepository implements PlayerRepository {
  @override
  Future<void> stopPlayback({required String sessionId}) async {}

  @override
  Future<void> disposePlayback({required String sessionId}) async {}

  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    throw const NoPlayableVideoException();
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return const Stream.empty();
  }
}

class _DeferredSourceRepository implements PlayerRepository {
  @override
  Future<void> stopPlayback({required String sessionId}) async {}

  final Completer<PreparedPlayerSource> _prepareCompleter =
      Completer<PreparedPlayerSource>();
  final List<String> disposedSessionIds = [];
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
  Future<void> disposePlayback({required String sessionId}) async {
    disposedSessionIds.add(sessionId);
  }

  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) {
    cancellations.add(cancelled);
    return _prepareCompleter.future;
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return const Stream.empty();
  }
}
