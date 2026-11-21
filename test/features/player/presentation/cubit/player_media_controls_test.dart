import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/player_media_controls.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/playback/player_engine.dart';

import '../../../../helpers/fake_player_engine.dart';
import '../../../../helpers/fake_player_repository.dart';
import '../../player_test_doubles.dart';

const _first = PlayerVideoFile(
  index: 2,
  name: 'episode-02.mkv',
  size: 0,
  extension: 'mkv',
);
const _second = PlayerVideoFile(
  index: 3,
  name: 'episode-03.mkv',
  size: 0,
  extension: 'mkv',
);

void main() {
  late FakePlayerEngine engine;
  late _MediaControls controls;
  late StubPlayerRepository repository;
  late DateTime now;

  setUp(() {
    engine = FakePlayerEngine();
    now = DateTime.utc(2026);
    controls = _MediaControls();
    repository = StubPlayerRepository(
      launches: (index) => Stream.value(
        PlayerLaunchReadyUpdate(
          PlayerSession(sessionId: '42', streamUrl: 'http://localhost/$index'),
        ),
      ),
    );
  });

  PlayerCubit createCubit({List<PlayerVideoFile> files = const [_first]}) {
    final source = fmaPlayerSource;
    final cubit = PlayerCubit(
      source: AnimePlayerSource(
        animeId: source.animeId,
        animeTitle: source.animeTitle,
        sourceTitle: source.sourceTitle,
        sessionId: source.sessionId,
        fileIndex: _first.index,
        fileName: _first.name,
        files: files,
      ),
      engine: engine,
      repository: repository,
      mediaControls: controls,
      now: () => now,
      mediaTitles: (source) => (
        title: source.animeTitle,
        episode: 'Episode ${source.episodeNumber}',
      ),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<void> playback({
    int position = 17,
    int duration = 24 * 60,
    bool playing = true,
    bool buffering = false,
    double rate = 1,
    Duration? seek,
  }) async {
    engine.mediaPlayback = (
      position: Duration(seconds: position),
      duration: Duration(seconds: duration),
      playing: playing,
      buffering: buffering,
      rate: rate,
    );
    engine.emit(PlayerEngineMediaChanged(seekPosition: seek));
    await pumpEventQueue(times: 1);
  }

  test(
    'publishes ready metadata and recalibrates the system clock on transitions',
    () async {
      final cubit = createCubit();
      await cubit.loadPlayback();
      expect(controls.updates, isEmpty);

      await playback();
      expect(controls.updates.single.titles, (
        title: fmaPlayerSource.animeTitle,
        episode: 'Episode 2',
      ));
      expect(
        controls.updates.single.playback.duration,
        const Duration(minutes: 24),
      );
      expect(
        controls.updates.single.playback.position,
        const Duration(seconds: 17),
      );

      for (var tick = 1; tick <= 6; tick++) {
        engine.emit(
          PlayerEngineProgress(
            Duration(milliseconds: 17000 + tick * 200),
            const Duration(minutes: 24),
          ),
        );
      }
      await playback(position: 19);
      expect(controls.updates, hasLength(1));

      await playback(position: 19, playing: false);
      expect(controls.updates.last.playback.playing, isFalse);
      expect(
        controls.updates.last.playback.position,
        const Duration(seconds: 19),
      );
      await playback(position: 19, buffering: true);
      expect(controls.updates.last.playback.buffering, isTrue);
      await playback(position: 20);
      expect(controls.updates.last.playback.buffering, isFalse);
      await playback(position: 21, rate: 1.5);
      expect(controls.updates.last.playback.rate, 1.5);
      await playback(position: 23, rate: 1.5, duration: 1460);
      expect(
        controls.updates.last.playback.duration,
        const Duration(seconds: 1460),
      );
      await playback(
        position: 23,
        rate: 1.5,
        duration: 1460,
        seek: const Duration(seconds: 7),
      );
      expect(
        controls.updates.last.playback.position,
        const Duration(seconds: 7),
      );
      expect(controls.updates, hasLength(7));
    },
  );

  test(
    'handles media keys and noisy pause, and bounds seeks to the known duration',
    () async {
      final cubit = createCubit();
      await cubit.loadPlayback();
      await playback(position: 20, duration: 25);
      final command = controls.handler!;
      await command(PlayerMediaCommand.play, null);
      await command(PlayerMediaCommand.togglePlayPause, null);
      await command(PlayerMediaCommand.seekBackward, null);
      await command(PlayerMediaCommand.seekForward, null);
      await command(PlayerMediaCommand.seekTo, const Duration(seconds: -1));
      await command(PlayerMediaCommand.seekTo, const Duration(seconds: 9));
      await command(PlayerMediaCommand.seekTo, const Duration(seconds: 30));
      expect(engine.calls.skip(1), [
        'play',
        'pause',
        'seek 0:00:10.000000',
        'seek 0:00:20.000000',
        'seek 0:00:00.000000',
        'seek 0:00:09.000000',
        'seek 0:00:25.000000',
      ]);

      await playback(playing: false, duration: 0);
      await command(PlayerMediaCommand.togglePlayPause, null);
      expect(engine.calls.last, 'play');
      final before = engine.calls.length;
      await command(PlayerMediaCommand.seekTo, const Duration(seconds: 5));
      await command(PlayerMediaCommand.next, null);
      expect(engine.calls, hasLength(before));
      expect(controls.updates.last.canNext, isFalse);

      engine.allowsStartingMediaPlayback = false;
      await command(PlayerMediaCommand.togglePlayPause, null);
      await command(PlayerMediaCommand.play, null);
      expect(engine.calls, hasLength(before));
      await command(PlayerMediaCommand.pauseImmediately, null);
      expect(engine.calls.length, before + 1);
      expect(engine.calls.last, 'pause immediately');
    },
  );

  test('a system Pause stops a buffering stream', () async {
    final cubit = createCubit();
    await cubit.loadPlayback();
    await playback(buffering: true, duration: 0);
    expect(controls.updates.single.playback.buffering, isTrue);
    engine.allowsStartingMediaPlayback = false;
    await controls.handler!(PlayerMediaCommand.pause, null);
    expect(engine.calls.last, 'pause');
  });

  test('rapid system skips accumulate until the seek settles', () async {
    final cubit = createCubit();
    await cubit.loadPlayback();
    await playback(position: 20);
    final command = controls.handler!;
    await Future.wait([
      command(PlayerMediaCommand.seekForward, null),
      command(PlayerMediaCommand.seekForward, null),
    ]);
    expect(engine.calls.skip(1), [
      'seek 0:00:30.000000',
      'seek 0:00:40.000000',
    ]);

    await playback(position: 40);
    await command(PlayerMediaCommand.seekBackward, null);
    expect(engine.calls.last, 'seek 0:00:30.000000');
    // No reply arrived for the backward seek. Use the real clock again.
    now = now.add(const Duration(seconds: 1));
    await command(PlayerMediaCommand.seekForward, null);
    expect(engine.calls.last, 'seek 0:00:50.000000');

    await command(PlayerMediaCommand.seekTo, const Duration(seconds: 8));
    await playback(position: 8);
    await command(PlayerMediaCommand.seekForward, null);
    expect(engine.calls.last, 'seek 0:00:18.000000');
  });

  test('switching files drops the previous file’s pending seek', () async {
    final cubit = createCubit(files: const [_first, _second]);
    await cubit.loadPlayback();
    await playback(position: 60);
    await controls.handler!(PlayerMediaCommand.seekForward, null);
    expect(engine.calls.last, 'seek 0:01:10.000000');

    await controls.handler!(PlayerMediaCommand.next, null);
    await playback(position: 3);
    await controls.handler!(PlayerMediaCommand.seekForward, null);
    expect(engine.calls.last, 'seek 0:00:13.000000');
  });

  test(
    'a completed file uses its end position for the next system seek',
    () async {
      final cubit = createCubit();
      await cubit.loadPlayback();
      await playback(position: 70, duration: 100);
      await controls.handler!(PlayerMediaCommand.seekForward, null);
      expect(engine.calls.last, 'seek 0:01:20.000000');

      await playback(position: 100, duration: 100, playing: false);
      engine.emit(const PlayerEngineCompleted());
      await pumpEventQueue(times: 1);
      await controls.handler!(PlayerMediaCommand.seekBackward, null);
      expect(engine.calls.last, 'seek 0:01:30.000000');
    },
  );

  test(
    'Next advertises the following episode and retires the old session',
    () async {
      final cubit = createCubit(files: const [_first, _second]);
      await cubit.loadPlayback();
      await playback();
      expect(controls.updates.single.canNext, isTrue);
      final firstHandler = controls.handler!;

      engine.allowsStartingMediaPlayback = false;
      await firstHandler(PlayerMediaCommand.next, null);
      expect(repository.startedFileIndices, [_first.index]);
      engine.allowsStartingMediaPlayback = true;
      engine.mediaPlayback = null;
      // Engine is between playable files: a carried-over event has no target.
      await firstHandler(PlayerMediaCommand.play, null);
      expect(engine.calls, hasLength(1));
      await playback();
      await firstHandler(PlayerMediaCommand.next, null);
      expect(repository.startedFileIndices, [_first.index, _second.index]);
      expect(controls.deactivations, 1);
      expect(controls.handler, isNull);
      await playback();
      expect(controls.updates.last.titles.episode, 'Episode 3');
      expect(controls.updates.last.canNext, isFalse);
      final before = engine.calls.length;
      await firstHandler(PlayerMediaCommand.pause, null);
      expect(engine.calls, hasLength(before));
    },
  );

  test(
    'clears system controls at the start of close and ignores queued commands',
    () async {
      final cubit = createCubit();
      await cubit.loadPlayback();
      await playback();
      final command = controls.handler!;
      final gate = engine.closeGate = Completer<void>();
      final closing = cubit.close();
      try {
        await pumpEventQueue(times: 1);
        expect(engine.calls.last, 'close');
        expect(controls.deactivations, 1);
        await command(PlayerMediaCommand.play, null);
        await playback(playing: false);
        expect(controls.updates, hasLength(1));
        expect(engine.calls.last, 'close');
      } finally {
        gate.complete();
        await closing;
      }
      await command(PlayerMediaCommand.pause, null);
      expect(engine.calls.last, 'closed');
    },
  );
}

class _MediaControls implements PlayerMediaControls {
  final updates =
      <
        ({PlayerMediaTitles titles, PlayerMediaPlayback playback, bool canNext})
      >[];
  PlayerMediaCommandHandler? handler;
  int deactivations = 0;

  @override
  Future<void> update({
    required PlayerMediaTitles titles,
    required PlayerMediaPlayback playback,
    required bool canNext,
    required PlayerMediaCommandHandler onCommand,
  }) async {
    updates.add((titles: titles, playback: playback, canNext: canNext));
    handler = onCommand;
  }

  @override
  Future<void> deactivate() async {
    handler = null;
    deactivations++;
  }
}
