import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_launch_failure.dart';
import 'package:iris/features/player/domain/entities/player_launch_progress.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';

void main() {
  test(
    'emits preparation progress then ready when playback starts for selected file',
    () async {
      final cubit = PlayerCubit(
        source: _source,
        repository: _SuccessPlayerRepository(
          const PlayerSession(
            sessionId: '42',
            streamUrl: 'http://127.0.0.1:8080/stream/2',
          ),
        ),
      );

      expectLater(
        cubit.stream,
        emitsInOrder([
          const PlayerPreparing(progress: PlayerLaunchProgress.initial()),
          const PlayerPreparing(
            progress: PlayerLaunchProgress(
              bufferProgress: 0.25,
              downloadRateBytesPerSecond: 2048,
              stage: PlayerLaunchStage.preparing,
            ),
          ),
          const PlayerReady(
            PlayerSession(
              sessionId: '42',
              streamUrl: 'http://127.0.0.1:8080/stream/2',
            ),
          ),
        ]),
      );

      await cubit.loadPlayback();
    },
  );

  test('emits generic failure when repository throws', () async {
    final repository = _FailingPlayerRepository();
    final cubit = PlayerCubit(source: _source, repository: repository);

    expectLater(
      cubit.stream,
      emitsInOrder([
        const PlayerPreparing(progress: PlayerLaunchProgress.initial()),
        const PlayerFailure(PlayerLaunchFailure.unableToStart),
      ]),
    );

    await cubit.loadPlayback();

    expect(repository.disposedSessionIds, ['42']);
  });

  test(
    'emits startup buffer failure when repository reports stalled buffer',
    () async {
      final repository = _StartupBufferFailingPlayerRepository();
      final cubit = PlayerCubit(source: _source, repository: repository);

      expectLater(
        cubit.stream,
        emitsInOrder([
          const PlayerPreparing(progress: PlayerLaunchProgress.initial()),
          const PlayerPreparing(
            progress: PlayerLaunchProgress(
              bufferProgress: 0.125,
              downloadRateBytesPerSecond: 8192,
              stage: PlayerLaunchStage.waitingForBuffer,
            ),
          ),
          const PlayerFailure(PlayerLaunchFailure.unableToPrepareStartupBuffer),
        ]),
      );

      await cubit.loadPlayback();

      expect(repository.disposedSessionIds, ['42']);
    },
  );

  test('disposes active playback on close', () async {
    final repository = _SuccessPlayerRepository(
      const PlayerSession(
        sessionId: '42',
        streamUrl: 'http://127.0.0.1:8080/stream/2',
      ),
    );
    final cubit = PlayerCubit(source: _source, repository: repository);

    await cubit.loadPlayback();
    await cubit.close();

    expect(repository.startedSessionIds, ['42']);
    expect(repository.startedFileIndices, [2]);
    expect(repository.disposedSessionIds, ['42']);
  });

  test(
    'ignores repeated loadPlayback while launch is already active',
    () async {
      final repository = _ControlledPlayerRepository();
      final cubit = PlayerCubit(source: _source, repository: repository);

      final firstLaunch = cubit.loadPlayback();
      await Future<void>.delayed(Duration.zero);
      cubit.loadPlayback();

      expect(repository.startedSessionIds, ['42']);
      expect(repository.startedFileIndices, [2]);

      repository.emit(
        const PlayerLaunchReadyUpdate(
          PlayerSession(
            sessionId: '42',
            streamUrl: 'http://127.0.0.1:8080/stream/2',
          ),
        ),
      );
      await firstLaunch;
    },
  );

  test('cancels active launch subscription when cubit closes', () async {
    final repository = _ControlledPlayerRepository();
    final cubit = PlayerCubit(source: _source, repository: repository);

    cubit.loadPlayback();
    await Future<void>.delayed(Duration.zero);

    await cubit.close();

    expect(repository.cancelledLaunchCount, 1);
    expect(repository.disposedSessionIds, ['42']);
  });
}

class _SuccessPlayerRepository implements PlayerRepository {
  _SuccessPlayerRepository(this.session);

  final PlayerSession session;
  final List<String> startedSessionIds = [];
  final List<int> startedFileIndices = [];
  final List<String> disposedSessionIds = [];

  @override
  Future<void> disposePlayback({required String sessionId}) async {
    disposedSessionIds.add(sessionId);
  }

  @override
  Future<PreparedPlayerSource> prepareSource({required String magnet}) {
    throw UnimplementedError();
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) async* {
    startedSessionIds.add(sessionId);
    startedFileIndices.add(fileIndex);
    yield const PlayerLaunchProgressUpdate(
      PlayerLaunchProgress(
        bufferProgress: 0.25,
        downloadRateBytesPerSecond: 2048,
        stage: PlayerLaunchStage.preparing,
      ),
    );
    yield PlayerLaunchReadyUpdate(session);
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return const Stream.empty();
  }
}

class _FailingPlayerRepository implements PlayerRepository {
  final List<String> disposedSessionIds = [];

  @override
  Future<void> disposePlayback({required String sessionId}) async {
    disposedSessionIds.add(sessionId);
  }

  @override
  Future<PreparedPlayerSource> prepareSource({required String magnet}) {
    throw UnimplementedError();
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) async* {
    yield const PlayerLaunchFailureUpdate(PlayerLaunchFailure.unableToStart);
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return const Stream.empty();
  }
}

class _StartupBufferFailingPlayerRepository implements PlayerRepository {
  final List<String> disposedSessionIds = [];

  @override
  Future<void> disposePlayback({required String sessionId}) async {
    disposedSessionIds.add(sessionId);
  }

  @override
  Future<PreparedPlayerSource> prepareSource({required String magnet}) {
    throw UnimplementedError();
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) async* {
    yield const PlayerLaunchProgressUpdate(
      PlayerLaunchProgress(
        bufferProgress: 0.125,
        downloadRateBytesPerSecond: 8192,
        stage: PlayerLaunchStage.waitingForBuffer,
      ),
    );
    yield const PlayerLaunchFailureUpdate(
      PlayerLaunchFailure.unableToPrepareStartupBuffer,
    );
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return const Stream.empty();
  }
}

class _ControlledPlayerRepository implements PlayerRepository {
  final List<String> startedSessionIds = [];
  final List<int> startedFileIndices = [];
  final List<String> disposedSessionIds = [];
  int cancelledLaunchCount = 0;
  StreamController<PlayerLaunchUpdate>? _controller;

  @override
  Future<void> disposePlayback({required String sessionId}) async {
    disposedSessionIds.add(sessionId);
  }

  void emit(PlayerLaunchUpdate update) {
    _controller?.add(update);
  }

  @override
  Future<PreparedPlayerSource> prepareSource({required String magnet}) {
    throw UnimplementedError();
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) {
    startedSessionIds.add(sessionId);
    startedFileIndices.add(fileIndex);
    final controller = StreamController<PlayerLaunchUpdate>(
      onCancel: () {
        cancelledLaunchCount++;
      },
    );
    _controller = controller;
    return controller.stream;
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return const Stream.empty();
  }
}

const _source = AnimePlayerSource(
  animeId: '5114',
  animeTitle: 'Fullmetal Alchemist: Brotherhood',
  sourceTitle: '[Mock] Fullmetal Alchemist: Brotherhood Batch',
  sessionId: '42',
  fileIndex: 2,
  fileName: 'episode-02.mkv',
);
