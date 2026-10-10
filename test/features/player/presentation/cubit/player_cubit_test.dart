import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';

import '../../../../helpers/fake_player_engine.dart';

void main() {
  test(
    'emits preparation progress then ready when playback starts for selected file',
    () async {
      final cubit = PlayerCubit(
        source: _source,
        engine: FakePlayerEngine(),
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
          const PlayerPreparing(),
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
    final cubit = PlayerCubit(
      source: _source,
      repository: repository,
      engine: FakePlayerEngine(),
    );

    expectLater(
      cubit.stream,
      emitsInOrder([const PlayerPreparing(), const PlayerFailure()]),
    );

    await cubit.loadPlayback();

    expect(repository.disposedSessionIds, isEmpty);
  });

  test(
    'keeps the session after a failed launch, so retry starts it again',
    () async {
      final repository = _ScriptedPlayerRepository([
        Stream.value(const PlayerLaunchFailureUpdate()),
        Stream.value(const PlayerLaunchReadyUpdate(_playerSession)),
      ]);
      final engine = FakePlayerEngine();
      final cubit = PlayerCubit(
        source: _source,
        repository: repository,
        engine: engine,
      );

      await cubit.loadPlayback();

      expect(cubit.state, const PlayerFailure());
      expect(repository.disposedSessionIds, isEmpty);

      await cubit.loadPlayback();

      expect(repository.startedSessionIds, ['42', '42']);
      expect(cubit.state, const PlayerReady(_playerSession));
      expect(engine.calls, ['open http://127.0.0.1:8080/stream/2']);
      expect(repository.disposedSessionIds, isEmpty);

      await cubit.close();
      expect(repository.disposedSessionIds, ['42']);
    },
  );

  test(
    'keeps the session when the launch stream fails, so retry starts it again',
    () async {
      final repository = _ScriptedPlayerRepository([
        Stream.error(StateError('stream broke')),
        Stream.value(const PlayerLaunchReadyUpdate(_playerSession)),
      ]);
      final cubit = PlayerCubit(
        source: _source,
        repository: repository,
        engine: FakePlayerEngine(),
      );

      await cubit.loadPlayback();

      expect(cubit.state, const PlayerFailure());
      expect(repository.disposedSessionIds, isEmpty);

      await cubit.loadPlayback();

      expect(repository.startedSessionIds, ['42', '42']);
      expect(cubit.state, const PlayerReady(_playerSession));
      await cubit.close();
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
    final cubit = PlayerCubit(
      source: _source,
      repository: repository,
      engine: FakePlayerEngine(),
    );

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
      final cubit = PlayerCubit(
        source: _source,
        repository: repository,
        engine: FakePlayerEngine(),
      );

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
    final cubit = PlayerCubit(
      source: _source,
      repository: repository,
      engine: FakePlayerEngine(),
    );

    cubit.loadPlayback();
    await Future<void>.delayed(Duration.zero);

    await cubit.close();

    expect(repository.cancelledLaunchCount, 1);
    expect(repository.disposedSessionIds, ['42']);
  });

  test('opens the media player for the ready stream', () async {
    final engine = FakePlayerEngine();
    final cubit = PlayerCubit(
      source: _source,
      engine: engine,
      repository: _SuccessPlayerRepository(
        const PlayerSession(
          sessionId: '42',
          streamUrl: 'http://127.0.0.1:8080/stream/2',
        ),
      ),
    );
    addTearDown(cubit.close);

    await cubit.loadPlayback();

    expect(engine.calls, ['open http://127.0.0.1:8080/stream/2']);
  });

  test(
    'disposes the session only after the media player released the stream',
    () async {
      final repository = _SuccessPlayerRepository(
        const PlayerSession(
          sessionId: '42',
          streamUrl: 'http://127.0.0.1:8080/stream/2',
        ),
      );
      final engine = FakePlayerEngine()..closeGate = Completer<void>();
      final cubit = PlayerCubit(
        source: _source,
        repository: repository,
        engine: engine,
      );
      await cubit.loadPlayback();

      final closing = cubit.close();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repository.disposedSessionIds, isEmpty);

      engine.closeGate!.complete();
      await closing;
      expect(repository.disposedSessionIds, ['42']);
    },
  );

  test('disposes the session anyway when the release times out', () async {
    final repository = _SuccessPlayerRepository(
      const PlayerSession(
        sessionId: '42',
        streamUrl: 'http://127.0.0.1:8080/stream/2',
      ),
    );
    final cubit = PlayerCubit(
      source: _source,
      repository: repository,
      engine: FakePlayerEngine()..closeGate = Completer<void>(),
      engineReleaseTimeout: const Duration(milliseconds: 50),
    );
    await cubit.loadPlayback();

    await cubit.close();

    expect(repository.disposedSessionIds, ['42']);
  });
}

class _SuccessPlayerRepository implements PlayerRepository {
  @override
  Future<void> stopPlayback({required String sessionId}) async {}

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
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) async* {
    startedSessionIds.add(sessionId);
    startedFileIndices.add(fileIndex);
    yield PlayerLaunchReadyUpdate(session);
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return const Stream.empty();
  }
}

class _FailingPlayerRepository implements PlayerRepository {
  @override
  Future<void> stopPlayback({required String sessionId}) async {}

  final List<String> disposedSessionIds = [];

  @override
  Future<void> disposePlayback({required String sessionId}) async {
    disposedSessionIds.add(sessionId);
  }

  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) async* {
    yield const PlayerLaunchFailureUpdate();
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return const Stream.empty();
  }
}

class _ControlledPlayerRepository implements PlayerRepository {
  @override
  Future<void> stopPlayback({required String sessionId}) async {}

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
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) {
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

/// Answers each start with the next scripted stream.
class _ScriptedPlayerRepository implements PlayerRepository {
  _ScriptedPlayerRepository(this._launches);

  final List<Stream<PlayerLaunchUpdate>> _launches;
  final List<String> startedSessionIds = [];
  final List<String> disposedSessionIds = [];

  @override
  Future<void> stopPlayback({required String sessionId}) async {}

  @override
  Future<void> disposePlayback({required String sessionId}) async {
    disposedSessionIds.add(sessionId);
  }

  @override
  Future<PreparedPlayerSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) {
    startedSessionIds.add(sessionId);
    return _launches.removeAt(0);
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return const Stream.empty();
  }
}

const _playerSession = PlayerSession(
  sessionId: '42',
  streamUrl: 'http://127.0.0.1:8080/stream/2',
);

const _source = AnimePlayerSource(
  animeId: '5114',
  animeTitle: 'Fullmetal Alchemist: Brotherhood',
  sourceTitle: '[Mock] Fullmetal Alchemist: Brotherhood Batch',
  sessionId: '42',
  fileIndex: 2,
  fileName: 'episode-02.mkv',
);
