import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';

import '../../../../helpers/fake_player_engine.dart';
import '../../../../helpers/fake_player_repository.dart';
import '../../player_test_doubles.dart';

void main() {
  test(
    'emits preparing then ready when playback starts for the selected file',
    () async {
      final cubit = PlayerCubit(
        source: fmaPlayerSource,
        engine: FakePlayerEngine(),
        repository: _readyRepository(),
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

  test('a failed launch update ends in the generic failure', () async {
    final repository = _scriptedRepository([
      Stream.value(const PlayerLaunchFailureUpdate()),
    ]);
    final cubit = PlayerCubit(
      source: fmaPlayerSource,
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
      final repository = _scriptedRepository([
        Stream.value(const PlayerLaunchFailureUpdate()),
        Stream.value(const PlayerLaunchReadyUpdate(_playerSession)),
      ]);
      final engine = FakePlayerEngine();
      final cubit = PlayerCubit(
        source: fmaPlayerSource,
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
      final repository = _scriptedRepository([
        Stream.error(StateError('stream broke')),
        Stream.value(const PlayerLaunchReadyUpdate(_playerSession)),
      ]);
      final cubit = PlayerCubit(
        source: fmaPlayerSource,
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
    final repository = _readyRepository();
    final cubit = PlayerCubit(
      source: fmaPlayerSource,
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
        source: fmaPlayerSource,
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
      source: fmaPlayerSource,
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
      source: fmaPlayerSource,
      engine: engine,
      repository: _readyRepository(),
    );
    addTearDown(cubit.close);

    await cubit.loadPlayback();

    expect(engine.calls, ['open http://127.0.0.1:8080/stream/2']);
  });

  test(
    'disposes the session only after the media player released the stream',
    () async {
      final repository = _readyRepository();
      final engine = FakePlayerEngine()..closeGate = Completer<void>();
      final cubit = PlayerCubit(
        source: fmaPlayerSource,
        repository: repository,
        engine: engine,
      );
      await cubit.loadPlayback();

      final closing = cubit.close();
      await pumpEventQueue();
      expect(repository.disposedSessionIds, isEmpty);

      engine.closeGate!.complete();
      await closing;
      expect(repository.disposedSessionIds, ['42']);
    },
  );

  test('disposes the session anyway when the release times out', () async {
    final repository = _readyRepository();
    final cubit = PlayerCubit(
      source: fmaPlayerSource,
      repository: repository,
      engine: FakePlayerEngine()..closeGate = Completer<void>(),
      engineReleaseTimeout: const Duration(milliseconds: 50),
    );
    await cubit.loadPlayback();

    await cubit.close();

    expect(repository.disposedSessionIds, ['42']);
  });
}

StubPlayerRepository _readyRepository() {
  return StubPlayerRepository(
    launches: (_) =>
        Stream.value(const PlayerLaunchReadyUpdate(_playerSession)),
  );
}

/// Answers each start with the next scripted stream.
StubPlayerRepository _scriptedRepository(
  List<Stream<PlayerLaunchUpdate>> launches,
) {
  return StubPlayerRepository(launches: (_) => launches.removeAt(0));
}

class _ControlledPlayerRepository extends StubPlayerRepository {
  int cancelledLaunchCount = 0;
  StreamController<PlayerLaunchUpdate>? _controller;

  void emit(PlayerLaunchUpdate update) {
    _controller?.add(update);
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
}

const _playerSession = PlayerSession(
  sessionId: '42',
  streamUrl: 'http://127.0.0.1:8080/stream/2',
);
