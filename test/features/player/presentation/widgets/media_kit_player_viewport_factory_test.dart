import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/playback/media_kit_player_engine.dart';
import 'package:iris/features/player/presentation/widgets/media_kit_player_viewport_factory.dart';
import 'package:iris/features/player/presentation/widgets/player_auto_hiding_offer.dart';
import 'package:iris/features/player/presentation/widgets/player_immersive_controls.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/features/player/presentation/widgets/player_overlay_preferences.dart';
import 'package:iris/features/player/presentation/widgets/player_track_selector_sheet.dart';
import 'package:iris/features/player/presentation/widgets/player_wait_indicator.dart';

import '../../../../helpers/fake_player_repository.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';
import '../../player_test_doubles.dart';

void main() {
  testWidgets('keeps the tracks button available before and after the '
      'first frame', (tester) async {
    final firstFrameCompleter = Completer<void>();
    await tester.pumpWidget(
      _wrapViewport(firstFrameFuture: firstFrameCompleter.future),
    );
    await tester.pump();

    expect(find.byKey(const Key('player_tracks_button')), findsOneWidget);

    firstFrameCompleter.complete();
    await tester.pump();

    expect(find.byKey(const Key('player_tracks_button')), findsOneWidget);
  });

  testWidgets(
    'keeps viewport in local buffering state until the first frame is rendered',
    (tester) async {
      final firstFrameCompleter = Completer<void>();
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );

      await tester.pumpWidget(
        _wrapViewport(
          platformPlayer: platformPlayer,
          firstFrameFuture: firstFrameCompleter.future,
        ),
      );
      await tester.pump();

      expect(find.text('Buffering'), findsAtLeastNWidgets(1));
      expect(find.byKey(const Key('player_video_surface')), findsOneWidget);
      expect(find.byType(BlockRunner), findsOneWidget);

      firstFrameCompleter.complete();
      await tester.pump();

      expect(find.text('Buffering'), findsNothing);
    },
  );

  testWidgets('becomes ready from the duration and a real video track, '
      'and keeps buffering on screen until the first frame', (tester) async {
    final firstFrameCompleter = Completer<void>();
    final platformPlayer = _FakePlatformPlayer(
      configuration: const PlayerConfiguration(),
    );
    late MediaKitPlayerEngine engine;

    await tester.pumpWidget(
      _wrapViewport(
        platformPlayer: platformPlayer,
        firstFrameFuture: firstFrameCompleter.future,
        onEngine: (value) => engine = value,
      ),
    );
    await tester.pump();

    platformPlayer.emitDuration(const Duration(minutes: 107));
    platformPlayer.emitTracks(
      const Tracks(
        video: [
          VideoTrack('auto', null, null),
          VideoTrack('no', null, null),
          VideoTrack('1', 'Main Video', 'jpn'),
        ],
      ),
    );
    await tester.pump();

    expect(engine.phase.value, PlayerEnginePhase.ready);
    // As on desktop: a black frame alone would hide that the stream waits.
    expect(find.text('Buffering'), findsOneWidget);
    expect(find.byKey(const Key('player_startup_label')), findsOneWidget);

    firstFrameCompleter.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('Buffering'), findsNothing);
  });

  testWidgets('a hiccup mpv gets over is not shown as an error', (
    tester,
  ) async {
    final firstFrameCompleter = Completer<void>();
    final platformPlayer = _FakePlatformPlayer(
      configuration: const PlayerConfiguration(),
    );

    await tester.pumpWidget(
      _wrapViewport(
        platformPlayer: platformPlayer,
        firstFrameFuture: firstFrameCompleter.future,
      ),
    );
    await tester.pump();

    // A segment that did not load; mpv still has the file.
    platformPlayer.emitError('tcp: ffurl_read returned 0xffffff99');
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Unable to start playback.'), findsNothing);

    firstFrameCompleter.complete();
    await tester.pump();
    expect(find.text('Unable to start playback.'), findsNothing);
    expect(platformPlayer.pauseCount, 0);
  });

  testWidgets('an error that ends the file is shown, with nothing behind it', (
    tester,
  ) async {
    final platformPlayer = _FakePlatformPlayer(
      configuration: const PlayerConfiguration(),
    );

    await tester.pumpWidget(
      _wrapViewport(
        platformPlayer: platformPlayer,
        firstFrameFuture: Completer<void>().future,
      ),
    );
    await tester.pump();

    platformPlayer
      ..emitError('Failed to recognize file format.')
      ..nativeProperties['idle-active'] = 'yes';
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Unable to start playback.'), findsOneWidget);
    expect(platformPlayer.pauseCount, 1);
  });

  testWidgets('retry after a failure goes on from where it stopped', (
    tester,
  ) async {
    final platformPlayer = await _failMidStream(tester);
    expect(find.text('Unable to start playback.'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pump();

    expect(platformPlayer.openCount, 2);
    expect(
      (platformPlayer.lastOpened! as Media).start,
      const Duration(minutes: 2),
    );
  });

  testWidgets('a stream mpv opens at the start is sent where it should be', (
    tester,
  ) async {
    final platformPlayer = await _failMidStream(tester);

    // mpv takes no notice of the start position and plays from 0.
    platformPlayer.nativeProperties['time-pos'] = '0.000000';
    await tester.tap(find.text('Try Again'));
    await _deliverPlayerEvent(tester);
    await tester.pump();

    expect(platformPlayer.seeks, [const Duration(minutes: 2)]);
  });

  testWidgets('a stream opened where it should be is not sought again', (
    tester,
  ) async {
    final platformPlayer = await _failMidStream(tester);

    platformPlayer.nativeProperties['time-pos'] = '120.040000';
    await tester.tap(find.text('Try Again'));
    await _deliverPlayerEvent(tester);
    await tester.pump();

    expect(platformPlayer.seeks, isEmpty);
  });

  testWidgets('shows a dedicated error, with nothing playing behind it, when '
      'media_kit does not prepare the first frame in time', (tester) async {
    final platformPlayer = _FakePlatformPlayer(
      configuration: const PlayerConfiguration(),
    );

    await tester.pumpWidget(
      _wrapViewport(
        platformPlayer: platformPlayer,
        firstFrameFuture: Completer<void>().future,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 46));

    expect(
      find.text(
        'The stream is open, but the player could not prepare the first frame.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try Again'), findsOneWidget);
    expect(platformPlayer.pauseCount, 1);
  });

  testWidgets(
    'shows only startup status on the overlay while waiting for the first frame',
    (tester) async {
      final firstFrameCompleter = Completer<void>();
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );
      final repository = _LateStatsPlayerRepository();

      await tester.pumpWidget(
        _wrapViewport(
          platformPlayer: platformPlayer,
          firstFrameFuture: firstFrameCompleter.future,
          repository: repository,
        ),
      );
      await tester.pump();

      repository.emitStat(
        const PlayerPlaybackStats(
          downloadRateBytesPerSecond: 3 * 1024 * 1024,
          appMemoryBytes: null,
          activePeers: 8,
          bufferSeconds: 12,
          bufferPieces: 16,
          readaheadWindow: 30,
        ),
      );
      await tester.pump();

      expect(find.text('Buffering'), findsOneWidget);
      expect(find.text('3.0 MB/s'), findsNothing);
      expect(find.text('8'), findsNothing);
      expect(find.text('53%'), findsNothing);

      repository.finishCancel();
    },
  );

  testWidgets(
    'keeps waiting for a torrent without peers and says it has none yet',
    (tester) async {
      final firstFrameCompleter = Completer<void>();
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );
      final repository = _LateStatsPlayerRepository();

      await tester.pumpWidget(
        _wrapViewport(
          platformPlayer: platformPlayer,
          firstFrameFuture: firstFrameCompleter.future,
          repository: repository,
        ),
      );
      await tester.pump();

      repository.emitStat(
        const PlayerPlaybackStats(
          downloadRateBytesPerSecond: 0,
          appMemoryBytes: null,
          activePeers: 0,
          bufferSeconds: 0,
          bufferPieces: 0,
          readaheadWindow: 30,
          isTorrent: true,
        ),
      );
      await tester.pump();
      // Past the old 15 s cut-off: mpv keeps waiting for the data.
      await tester.pump(const Duration(seconds: 16));

      expect(find.text('Unable to start playback.'), findsNothing);
      expect(find.text('No peers yet'), findsOneWidget);

      repository.finishCancel();
    },
  );

  testWidgets('ignores late playback stats after the player page closes', (
    tester,
  ) async {
    final firstFrameCompleter = Completer<void>()..complete();
    final platformPlayer = _FakePlatformPlayer(
      configuration: const PlayerConfiguration(),
    );
    final repository = _LateStatsPlayerRepository();

    await tester.pumpWidget(
      _wrapViewport(
        platformPlayer: platformPlayer,
        firstFrameFuture: firstFrameCompleter.future,
        repository: repository,
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    repository.emitStat(
      const PlayerPlaybackStats(
        downloadRateBytesPerSecond: 1024,
        appMemoryBytes: 2048,
        activePeers: 3,
        bufferSeconds: 12,
        bufferPieces: 18,
        readaheadWindow: 30,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    repository.finishCancel();
  });

  testWidgets(
    'applies the latest subtitle renderer preference after queued recreates',
    (tester) async {
      final subtitleCubit = PlayerSubtitlePreferencesCubit(
        repository: MemorySubtitlePreferencesRepository(),
      );
      final slowOpenCompleter = Completer<void>();
      final createdPlayers = <_ControllablePlatformPlayer>[];

      await tester.pumpWidget(
        _wrapViewport(
          subtitleCubit: subtitleCubit,
          playerBuilder: (configuration) {
            final player = _ControllablePlatformPlayer(
              configuration: configuration,
              openFuture: createdPlayers.isEmpty
                  ? Future<void>.value()
                  : createdPlayers.length == 1
                  ? slowOpenCompleter.future
                  : Future<void>.value(),
            );
            createdPlayers.add(player);
            return Player(platformPlayer: player);
          },
          videoControllerBuilder: (player, configuration) =>
              _FakeVideoController(
                player: player,
                firstFrameFuture: Future<void>.value(),
              ),
        ),
      );
      await tester.pump();

      await subtitleCubit.setLibassEnabled(false);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      });
      for (
        var attempt = 0;
        attempt < 10 && createdPlayers.length < 2;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(createdPlayers.length, 2);
      expect(createdPlayers.last.configuration.libass, isFalse);

      await subtitleCubit.setLibassEnabled(true);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      });
      await tester.pump();
      await tester.pump();

      slowOpenCompleter.complete();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      });
      for (
        var attempt = 0;
        attempt < 10 && createdPlayers.length < 3;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(createdPlayers.length, 3);
      expect(createdPlayers.last.configuration.libass, isTrue);
    },
  );

  testWidgets(
    'passes decoding preferences into video controller configuration',
    (tester) async {
      late VideoControllerConfiguration capturedConfiguration;
      final decodingCubit = PlayerDecodingPreferencesCubit(
        repository: MemoryDecodingPreferencesRepository(
          const PlayerDecodingPreferences(
            hwdecMode: PlayerHwdecModePreset.softwareOnly,
          ),
        ),
      );
      await decodingCubit.loadPreferences();

      await tester.pumpWidget(
        _wrapViewport(
          decodingCubit: decodingCubit,
          videoControllerBuilder: (player, configuration) {
            capturedConfiguration = configuration;
            return _FakeVideoController(
              player: player,
              firstFrameFuture: Future<void>.value(),
            );
          },
        ),
      );
      await tester.pump();

      expect(capturedConfiguration.hwdec, 'no');
      expect(capturedConfiguration.enableHardwareAcceleration, isFalse);
    },
  );

  testWidgets('plays at the chosen speed, also in a new native player for '
      'a decoder change', (tester) async {
    final decodingCubit = PlayerDecodingPreferencesCubit(
      repository: MemoryDecodingPreferencesRepository(),
    );
    final createdPlayers = <_FakePlatformPlayer>[];
    late MediaKitPlayerEngine engine;

    await tester.pumpWidget(
      _wrapViewport(
        decodingCubit: decodingCubit,
        playerBuilder: (configuration) {
          final player = _FakePlatformPlayer(configuration: configuration);
          createdPlayers.add(player);
          return Player(platformPlayer: player);
        },
        onEngine: (value) => engine = value,
      ),
    );
    await tester.pump();
    expect(createdPlayers.single.rates, isEmpty, reason: 'normal speed');

    engine.setPlaybackRate(1.5);
    await tester.pump();
    expect(engine.playbackRate.value, 1.5);
    expect(createdPlayers.single.rates, [1.5]);

    await decodingCubit.setHwdecMode(PlayerHwdecModePreset.softwareOnly);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    });
    for (
      var attempt = 0;
      attempt < 10 &&
          (createdPlayers.length < 2 || createdPlayers.last.openCount == 0);
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(createdPlayers, hasLength(2));
    expect(createdPlayers.last.rates, [1.5]);
    expect(engine.playbackRate.value, 1.5);
  });

  testWidgets('plays at 2x while fast forward is held, then at the chosen '
      'speed again', (tester) async {
    final platformPlayer = _FakePlatformPlayer(
      configuration: const PlayerConfiguration(),
    );
    late MediaKitPlayerEngine engine;
    await tester.pumpWidget(
      _wrapViewport(
        platformPlayer: platformPlayer,
        onEngine: (value) => engine = value,
      ),
    );
    await tester.pump();

    engine.setPlaybackRate(1.25);
    engine.holdFastForward(true);
    await tester.pump();
    expect(platformPlayer.rates, [1.25, 2]);
    expect(engine.playbackRate.value, 1.25, reason: 'the choice stays');

    engine.holdFastForward(false);
    await tester.pump();
    expect(platformPlayer.rates.last, 1.25);

    // A chosen 2x is already as fast as the hold.
    engine.setPlaybackRate(2);
    engine.holdFastForward(true);
    engine.holdFastForward(false);
    await tester.pump();
    expect(platformPlayer.rates, [1.25, 2, 1.25, 2]);
  });

  testWidgets('plays the next file in the same player and video surface', (
    tester,
  ) async {
    final createdPlayers = <_FakePlatformPlayer>[];
    final controllers = <VideoController>{};
    late MediaKitPlayerEngine engine;

    await tester.pumpWidget(
      _wrapViewport(
        playerBuilder: (configuration) {
          final player = _FakePlatformPlayer(configuration: configuration);
          createdPlayers.add(player);
          return Player(platformPlayer: player);
        },
        onEngine: (value) => engine = value,
        videoSurfaceBuilder:
            ({
              required controller,
              required subtitleViewConfiguration,
              required controls,
              required fit,
            }) {
              controllers.add(controller);
              return _videoSurface;
            },
      ),
    );
    await tester.pump();
    expect(find.text('Buffering'), findsNothing);

    await tester.runAsync(engine.stop);
    await tester.pump();
    expect(find.text('Preparing video'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('player_video_surface')), findsOneWidget);

    unawaited(
      engine.open(
        const PlayerSession(
          sessionId: '42',
          streamUrl: 'http://127.0.0.1:8080/stream/3',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(createdPlayers, hasLength(1));
    expect(createdPlayers.single.openCount, 2);
    expect(controllers, hasLength(1));
    expect(find.text('Buffering'), findsNothing);
  });

  testWidgets('offers the next file in the credits for 8 s, then with the '
      'controls', (tester) async {
    setTestWindowSize(tester, TestWindowSizes.landscape);
    late _FakePlatformPlayer platformPlayer;

    await tester.pumpWidget(
      _wrapViewport(
        playerBuilder: (configuration) {
          platformPlayer = _FakePlatformPlayer(configuration: configuration);
          return Player(platformPlayer: platformPlayer);
        },
        next: PlayerNextFile(title: 'Episode 3', play: () {}),
      ),
    );
    await tester.pump();
    platformPlayer.emitDuration(const Duration(minutes: 24));
    platformPlayer.emitPosition(const Duration(minutes: 20));
    platformPlayer.emitPlaying(true);
    await _deliverPlayerEvent(tester);
    expect(find.byKey(_nextPrompt), findsNothing);

    platformPlayer.emitPosition(const Duration(minutes: 22));
    await _deliverPlayerEvent(tester);
    expect(find.text('Next episode'), findsOneWidget);
    expect(find.text('Episode 3'), findsOneWidget);
    expect(_nextPromptOpacity(tester), 1);
    expect(_nextPromptCountdown(), findsOneWidget);

    // The countdown starts with the next frame; the controls went before.
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    expect(_controlsOpacity(tester), 0);
    expect(_nextPromptOpacity(tester), 1, reason: 'its first 8 s');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(_nextPromptOpacity(tester), 0);

    // From then on it comes and goes with the controls, without a count.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    // Over the video, clear of the bars that hold the controls.
    await mouse.addPointer(location: const Offset(300, 300));
    await mouse.moveTo(const Offset(310, 300));
    await tester.pump();
    expect(_controlsOpacity(tester), 1);
    expect(_nextPromptOpacity(tester), 1);
    expect(_nextPromptCountdown(), findsNothing);
    await tester.pump(PlayerImmersiveControls.hideAfter);
    expect(_controlsOpacity(tester), 0);
    expect(_nextPromptOpacity(tester), 0);

    // Resting on it keeps the controls, and the offer with them.
    await mouse.moveTo(tester.getCenter(find.byKey(_nextPrompt)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(_controlsOpacity(tester), 1);
    expect(_nextPromptOpacity(tester), 1);
    await mouse.moveTo(const Offset(300, 300));
    await tester.pump(PlayerImmersiveControls.hideAfter);
    expect(_nextPromptOpacity(tester), 0);

    platformPlayer.emitPosition(const Duration(minutes: 10));
    await _deliverPlayerEvent(tester);
    expect(find.byKey(_nextPrompt), findsNothing);
  });

  testWidgets('by touch, offers the next file with the controls a tap '
      'brings up', (tester) async {
    setTestWindowSize(tester, const Size(844, 390));
    late _FakePlatformPlayer platformPlayer;

    await tester.pumpWidget(
      _wrapViewport(
        input: PlayerInputMode.touch,
        playerBuilder: (configuration) {
          platformPlayer = _FakePlatformPlayer(configuration: configuration);
          return Player(platformPlayer: platformPlayer);
        },
        next: PlayerNextFile(title: 'Episode 3', play: () {}),
      ),
    );
    await tester.pump();
    platformPlayer.emitDuration(const Duration(minutes: 24));
    platformPlayer.emitPosition(const Duration(minutes: 22));
    platformPlayer.emitPlaying(true);
    await _deliverPlayerEvent(tester);
    await tester.pump();
    await tester.pump(PlayerAutoHidingOffer.shownAtStart);
    await tester.pump();
    expect(_nextPromptOpacity(tester), 0);

    // In the middle a tap answers at once.
    const middle = Offset(422, 120);
    await tester.tapAt(middle);
    await tester.pump();
    expect(_nextPromptOpacity(tester), 1);
    expect(_nextPromptCountdown(), findsNothing);

    await tester.tapAt(middle);
    await tester.pump();
    expect(_nextPromptOpacity(tester), 0, reason: 'hidden with the controls');
  });

  testWidgets('offers the fixed skip for 8 s, then with the controls', (
    tester,
  ) async {
    setTestWindowSize(tester, TestWindowSizes.landscape);
    late _FakePlatformPlayer platformPlayer;
    await tester.pumpWidget(
      _wrapViewport(
        playerBuilder: (configuration) {
          platformPlayer = _FakePlatformPlayer(configuration: configuration);
          return Player(platformPlayer: platformPlayer);
        },
      ),
    );
    await tester.pump();
    platformPlayer.emitDuration(const Duration(minutes: 24));
    platformPlayer.emitPosition(const Duration(seconds: 40));
    platformPlayer.emitPlaying(true);
    await _deliverPlayerEvent(tester);
    double skipOpacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byKey(const Key('player_skip_forward_button')),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    expect(skipOpacity(), 1);

    await tester.pump();
    await tester.pump(PlayerAutoHidingOffer.shownAtStart);
    await tester.pump();
    expect(skipOpacity(), 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(const Offset(20, 20));
    await tester.pump();
    expect(skipOpacity(), 1);
  });

  testWidgets('offers to skip the opening named by a chapter', (tester) async {
    final platformPlayer = _FakePlatformPlayer(
      configuration: const PlayerConfiguration(),
    );
    platformPlayer.nativeProperties.addAll({
      'chapter-list/count': '3',
      'chapter-list/0/title': 'Prologue',
      'chapter-list/0/time': '0.000000',
      'chapter-list/1/title': 'Opening',
      'chapter-list/1/time': '95.500000',
      'chapter-list/2/title': 'Part A',
      'chapter-list/2/time': '185.500000',
    });

    await tester.pumpWidget(_wrapViewport(platformPlayer: platformPlayer));
    await tester.pump();
    platformPlayer.emitDuration(const Duration(minutes: 24));
    platformPlayer.emitPosition(const Duration(seconds: 30));
    await _deliverPlayerEvent(tester);
    expect(find.byKey(_skipSegmentButton), findsNothing);

    platformPlayer.emitPosition(const Duration(seconds: 100));
    await _deliverPlayerEvent(tester);
    expect(find.text('Skip opening'), findsOneWidget);

    await tester.tap(find.byKey(_skipSegmentButton));
    await tester.pump();
    expect(platformPlayer.seeks.last, const Duration(milliseconds: 185500));

    platformPlayer.emitPosition(const Duration(milliseconds: 185500));
    await _deliverPlayerEvent(tester);
    expect(find.byKey(_skipSegmentButton), findsNothing);
  });

  testWidgets('uses looked-up times for the opening and the next file', (
    tester,
  ) async {
    late _FakePlatformPlayer platformPlayer;
    late MediaKitPlayerEngine engine;

    await tester.pumpWidget(
      _wrapViewport(
        playerBuilder: (configuration) {
          platformPlayer = _FakePlatformPlayer(configuration: configuration);
          return Player(platformPlayer: platformPlayer);
        },
        onEngine: (value) => engine = value,
        next: PlayerNextFile(title: 'Episode 3', play: () {}),
      ),
    );
    await tester.pump();
    platformPlayer.emitDuration(const Duration(minutes: 24));
    platformPlayer.emitPosition(const Duration(minutes: 1));
    await _deliverPlayerEvent(tester);
    expect(engine.skipForwardOffered.value, isTrue);

    engine.useSkipTimes(const [
      PlayerSkipSegment(
        kind: PlayerSkipKind.opening,
        start: Duration(seconds: 50),
        end: Duration(seconds: 140),
      ),
      PlayerSkipSegment(
        kind: PlayerSkipKind.ending,
        start: Duration(minutes: 20),
        end: Duration(minutes: 21, seconds: 30),
      ),
    ]);
    await tester.pump();
    expect(find.byKey(_skipSegmentButton), findsOneWidget);
    expect(engine.skipForwardOffered.value, isFalse);

    platformPlayer.emitPosition(const Duration(minutes: 20, seconds: 5));
    await _deliverPlayerEvent(tester);
    expect(find.byKey(_skipSegmentButton), findsNothing);
    expect(find.byKey(_nextPrompt), findsOneWidget, reason: 'the ending began');
  });

  testWidgets('holds a seek asked for before the file loads until it can '
      'take it', (tester) async {
    late _FakePlatformPlayer platformPlayer;
    late MediaKitPlayerEngine engine;

    await tester.pumpWidget(
      _wrapViewport(
        playerBuilder: (configuration) {
          platformPlayer = _FakePlatformPlayer(configuration: configuration);
          return Player(platformPlayer: platformPlayer);
        },
        // No picture yet: the file is still loading.
        firstFrameFuture: Completer<void>().future,
        onEngine: (value) => engine = value,
      ),
    );
    await tester.pump();

    // mpv would drop it and go to the position the file was opened at.
    await tester.runAsync(() => engine.seek(Duration.zero));
    expect(platformPlayer.seeks, isEmpty);

    platformPlayer.emitDuration(const Duration(minutes: 24));
    await _deliverPlayerEvent(tester);
    expect(platformPlayer.seeks, [Duration.zero]);
  });

  testWidgets('offers a fixed skip early in a file with no known opening', (
    tester,
  ) async {
    late _FakePlatformPlayer platformPlayer;
    late MediaKitPlayerEngine engine;

    await tester.pumpWidget(
      _wrapViewport(
        playerBuilder: (configuration) {
          platformPlayer = _FakePlatformPlayer(configuration: configuration);
          return Player(platformPlayer: platformPlayer);
        },
        onEngine: (value) => engine = value,
      ),
    );
    await tester.pump();
    platformPlayer.emitDuration(const Duration(minutes: 24));
    platformPlayer.emitPosition(const Duration(seconds: 40));
    await _deliverPlayerEvent(tester);
    expect(engine.skipForwardOffered.value, isTrue);

    platformPlayer.state = platformPlayer.state.copyWith(
      position: const Duration(seconds: 40),
    );
    await tester.runAsync(engine.skipForward);
    expect(platformPlayer.seeks.last, const Duration(seconds: 125));

    platformPlayer.emitPosition(const Duration(minutes: 6));
    await _deliverPlayerEvent(tester);
    expect(engine.skipForwardOffered.value, isFalse);
  });

  testWidgets('waits for the looked-up times before the fixed skip', (
    tester,
  ) async {
    late _FakePlatformPlayer platformPlayer;
    late MediaKitPlayerEngine engine;

    await tester.pumpWidget(
      _wrapViewport(
        playerBuilder: (configuration) {
          platformPlayer = _FakePlatformPlayer(configuration: configuration);
          return Player(platformPlayer: platformPlayer);
        },
        onEngine: (value) => engine = value,
      ),
    );
    await tester.pump();
    engine.expectSkipTimes();
    platformPlayer.emitDuration(const Duration(minutes: 24));
    platformPlayer.emitPosition(const Duration(seconds: 40));
    await _deliverPlayerEvent(tester);
    expect(engine.skipForwardOffered.value, isFalse);

    engine.useSkipTimes(const []);
    await tester.pump();
    expect(engine.skipForwardOffered.value, isTrue);
  });

  testWidgets('keeps offering the next file once the current one ends', (
    tester,
  ) async {
    late _FakePlatformPlayer platformPlayer;
    var played = 0;

    await tester.pumpWidget(
      _wrapViewport(
        playerBuilder: (configuration) {
          platformPlayer = _FakePlatformPlayer(configuration: configuration);
          return Player(platformPlayer: platformPlayer);
        },
        next: PlayerNextFile(title: 'Episode 3', play: () => played++),
      ),
    );
    await tester.pump();

    platformPlayer.emitCompleted();
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));

    expect(_nextPromptOpacity(tester), 1);
    await tester.tap(find.byKey(_nextPrompt));
    expect(played, 1);
  });

  testWidgets('recreates the player when mpv does not release a stopped '
      'stream', (tester) async {
    final createdPlayers = <_StuckPlatformPlayer>[];
    late MediaKitPlayerEngine engine;

    await tester.pumpWidget(
      _wrapViewport(
        playerBuilder: (configuration) {
          final player = _StuckPlatformPlayer(configuration: configuration);
          createdPlayers.add(player);
          return Player(platformPlayer: player);
        },
        onEngine: (value) => engine = value,
      ),
    );
    await tester.pump();

    await tester.runAsync(engine.stop);

    expect(createdPlayers, hasLength(2));
    expect(createdPlayers.first.disposed, isTrue);
  });

  testWidgets('opens the session stream', (tester) async {
    final platformPlayer = _FakePlatformPlayer(
      configuration: const PlayerConfiguration(),
    );
    await tester.pumpWidget(
      _wrapViewport(
        platformPlayer: platformPlayer,
        session: const PlayerSession(
          sessionId: '7',
          streamUrl: 'https://video.example/episode/1.m3u8',
        ),
      ),
    );
    await tester.pump();

    expect(
      (platformPlayer.lastOpened! as Media).uri,
      'https://video.example/episode/1.m3u8',
    );
  });

  testWidgets('keep the playback stats coming when the next file opens on the '
      'same session', (tester) async {
    final repository = _SwitchingStatsPlayerRepository();
    addTearDown(repository.close);
    late MediaKitPlayerEngine engine;
    await tester.pumpWidget(
      _wrapViewport(
        repository: repository,
        onEngine: (created) => engine = created,
      ),
    );
    await tester.pump();

    repository.emit(0, _playbackStats(downloadRate: 1024));
    await tester.pump();
    expect(engine.playbackStats.value, _playbackStats(downloadRate: 1024));

    await engine.stop();
    expect(engine.playbackStats.value, isNull);
    repository.emit(0, _playbackStats(downloadRate: 2048));
    await tester.pump();
    expect(
      engine.playbackStats.value,
      isNull,
      reason: 'the stopped file no longer feeds the stats',
    );

    await engine.open(
      const PlayerSession(
        sessionId: '42',
        streamUrl: 'http://127.0.0.1:8080/stream/3',
      ),
    );
    expect(repository.watchedSessionIds, ['42', '42']);

    repository.emit(1, _playbackStats(downloadRate: 4096));
    await tester.pump();
    expect(engine.playbackStats.value, _playbackStats(downloadRate: 4096));
  });

  group('immersive controls', () {
    PlayerChrome chrome({
      VoidCallback? onBack,
      PlayerEpisodesBuilder? episodes,
      PlayerNotice? notice,
    }) {
      return PlayerChrome(
        title: 'Episode 11',
        overline: 'Frieren',
        details: '[SubsPlease] Frieren · 11 of 28',
        onBack: onBack ?? () {},
        episodes: episodes,
        notice: notice,
      );
    }

    testWidgets('draw the titles over a video that fills the window', (
      tester,
    ) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      var backs = 0;

      await tester.pumpWidget(
        _wrapViewport(
          chrome: chrome(onBack: () => backs++),
          videoSurfaceBuilder:
              ({
                required controller,
                required subtitleViewConfiguration,
                required controls,
                required fit,
              }) {
                return _videoSurface;
              },
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byKey(const Key('player_video_surface'))),
        TestWindowSizes.landscape,
      );
      expect(find.text('Frieren'), findsOneWidget);
      expect(find.text('[SubsPlease] Frieren · 11 of 28'), findsOneWidget);
      expect(find.text('Episode 11'), findsOneWidget);
      expect(find.byKey(const Key('player_seek_bar')), findsOneWidget);
      expect(find.byKey(const Key('player_episodes_button')), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('player_back_button')));
      expect(backs, 1);
    });

    for (final size in const [Size(800, 400), Size(800, 300)]) {
      testWidgets('fit the scrims in a ${size.height.toInt()} dp window', (
        tester,
      ) async {
        setTestWindowSize(tester, size);

        await tester.pumpWidget(_wrapViewport(chrome: chrome()));
        await tester.pump();

        expect(find.text('Frieren'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final width in const [360.0, 480.0, 600.0]) {
      testWidgets('fit every bar button in a ${width.toInt()} dp wide window', (
        tester,
      ) async {
        setTestWindowSize(tester, Size(width, 720));

        await tester.pumpWidget(
          _wrapViewport(
            chrome: chrome(episodes: (context, close) => const SizedBox()),
            next: PlayerNextFile(title: 'Episode 3', play: () {}),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        for (final key in const [
          'player_next_file_button',
          'player_episodes_button',
          'player_tracks_button',
          'player_settings_button',
          'player_fullscreen_button',
        ]) {
          final button = tester.getRect(find.byKey(Key(key)));
          expect(button.right, lessThanOrEqualTo(width), reason: key);
          expect(button.left, greaterThanOrEqualTo(0), reason: key);
        }
      });
    }

    testWidgets('keep both scrims at full size in a 600 dp window', (
      tester,
    ) async {
      Size scrim(String key) => tester.getSize(find.byKey(Key(key)));
      // A window tall enough that nothing has to give.
      setTestWindowSize(tester, const Size(800, 1200));
      await tester.pumpWidget(_wrapViewport(chrome: chrome()));
      await tester.pump();
      final fullTop = scrim('player_scrim_top');
      final fullBottom = scrim('player_scrim_bottom');

      setTestWindowSize(tester, const Size(800, 600));
      await tester.pump();

      expect(scrim('player_scrim_top'), fullTop);
      expect(scrim('player_scrim_bottom'), fullBottom);
      expect(tester.takeException(), isNull);
    });

    testWidgets('play, seek and change the volume from the keyboard', (
      tester,
    ) async {
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );
      await tester.pumpWidget(
        _wrapViewport(platformPlayer: platformPlayer, chrome: chrome()),
      );
      await tester.pump();
      platformPlayer.emitDuration(const Duration(minutes: 24));
      platformPlayer.emitPosition(const Duration(minutes: 5));
      await _deliverPlayerEvent(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(platformPlayer.playOrPauseCount, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(
        platformPlayer.seeks.last,
        const Duration(minutes: 5, seconds: 10),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      expect(
        platformPlayer.seeks.last,
        const Duration(minutes: 4, seconds: 50),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(platformPlayer.volumes.last, 95);
      await tester.pump();
      expect(find.byKey(const Key('player_volume_hud')), findsOneWidget);
      expect(find.text('95%'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      expect(platformPlayer.volumes.last, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      expect(platformPlayer.volumes.last, 95);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('player_volume_hud')), findsNothing);
    });

    testWidgets('switch the window to full screen and back, also when the '
        'player goes away', (tester) async {
      var entered = 0;
      var exited = 0;
      await tester.pumpWidget(
        _wrapViewport(
          chrome: chrome(),
          enterNativeFullscreen: () async => entered++,
          exitNativeFullscreen: () async => exited++,
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pump();
      expect(entered, 1);
      expect(find.bySemanticsLabel('Exit full screen'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(exited, 1);

      await tester.tap(find.byKey(const Key('player_fullscreen_button')));
      await tester.pump();
      expect(entered, 2);

      await tester.pumpWidget(const SizedBox());
      expect(exited, 2);
    });

    testWidgets('hide with the cursor during playback until the pointer '
        'moves', (tester) async {
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );
      await tester.pumpWidget(
        _wrapViewport(platformPlayer: platformPlayer, chrome: chrome()),
      );
      await tester.pump();
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.byKey(const Key('player_immersive_controls')),
          )
          .opacity;

      await tester.pump(const Duration(seconds: 4));
      expect(opacity(), 1, reason: 'paused playback keeps the controls');

      platformPlayer.emitPlaying(true);
      await _deliverPlayerEvent(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(opacity(), 0);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(400, 300));
      await mouse.moveTo(const Offset(410, 300));
      await tester.pump();
      expect(opacity(), 1);
      await mouse.removePointer();
    });

    testWidgets('open the episodes in a drawer that Escape closes', (
      tester,
    ) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      VoidCallback? closeDrawer;

      await tester.pumpWidget(
        _wrapViewport(
          chrome: chrome(
            episodes: (context, close) {
              closeDrawer = close;
              return const Text('Episode list');
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('player_episodes_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('player_episodes_drawer')), findsOneWidget);
      expect(find.text('Episode list'), findsOneWidget);
      final drawer = tester.getRect(
        find.byKey(const Key('player_episodes_drawer')),
      );
      // Over the right side, clear of the edge, the video still in view.
      const window = TestWindowSizes.landscape;
      expect(drawer.left, greaterThan(window.width / 2));
      expect(drawer.right, lessThan(window.width));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('player_episodes_drawer')), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pumpAndSettle();
      expect(find.text('Episode list'), findsOneWidget);
      closeDrawer!();
      await tester.pumpAndSettle();
      expect(find.text('Episode list'), findsNothing);
    });

    testWidgets('keep focus and screen readers inside the open episodes', (
      tester,
    ) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        _wrapViewport(
          chrome: chrome(
            episodes: (context, close) => Column(
              children: [
                TextButton(onPressed: () {}, child: const Text('Episode 1')),
                TextButton(onPressed: () {}, child: const Text('Episode 2')),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      // What a screen reader can move through.
      Iterable<String> readable() => tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.label);
      expect(readable(), contains('Audio & subtitles'));

      await tester.tap(find.byKey(const Key('player_episodes_button')));
      await tester.pumpAndSettle();
      final drawer = find.byKey(const Key('player_episodes_drawer'));
      bool focusInDrawer() {
        final focused = FocusManager.instance.primaryFocus?.context;
        return focused != null &&
            find
                .ancestor(of: find.byWidget(focused.widget), matching: drawer)
                .evaluate()
                .isNotEmpty;
      }

      expect(readable(), isNot(contains('Audio & subtitles')));
      expect(readable(), contains('Episode 1'));
      for (var press = 0; press < 6; press++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focusInDrawer(), isTrue, reason: 'Tab press ${press + 1}');
      }

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(drawer, findsNothing);
      expect(readable(), contains('Audio & subtitles'));
      semantics.dispose();
    });

    testWidgets('offer to skip the opening above the timeline', (tester) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );
      platformPlayer.nativeProperties.addAll({
        'chapter-list/count': '2',
        'chapter-list/0/title': 'Opening',
        'chapter-list/0/time': '0.000000',
        'chapter-list/1/title': 'Part A',
        'chapter-list/1/time': '90.000000',
      });
      await tester.pumpWidget(
        _wrapViewport(platformPlayer: platformPlayer, chrome: chrome()),
      );
      await tester.pump();
      platformPlayer.emitDuration(const Duration(minutes: 24));
      platformPlayer.emitPosition(const Duration(seconds: 10));
      await _deliverPlayerEvent(tester);

      expect(find.text('Skip opening'), findsOneWidget);
      final skip = tester.getRect(find.byKey(_skipSegmentButton));
      final seekBar = tester.getRect(find.byKey(const Key('player_seek_bar')));
      expect(skip.bottom, lessThan(seekBar.top));
      await tester.tap(find.byKey(_skipSegmentButton));
      await tester.pump();
      expect(platformPlayer.seeks.last, const Duration(seconds: 90));
    });

    testWidgets('put the startup spinner in place of the play button', (
      tester,
    ) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      final firstFrame = Completer<void>();
      await tester.pumpWidget(
        _wrapViewport(firstFrameFuture: firstFrame.future, chrome: chrome()),
      );
      await tester.pump();

      expect(find.text('Buffering'), findsOneWidget);
      final spinner = tester.getCenter(
        find.byKey(const Key('player_buffering_spinner')),
      );
      final backward = tester.getCenter(
        find.byKey(const Key('player_seek_backward_button')),
      );
      final forward = tester.getCenter(
        find.byKey(const Key('player_seek_forward_button')),
      );
      expect(spinner.dy, closeTo(backward.dy, 0.5));
      expect(spinner.dx, closeTo((backward.dx + forward.dx) / 2, 0.5));
      expect(
        tester.getTopLeft(find.text('Buffering')).dy,
        greaterThan(
          tester
              .getRect(find.byKey(const Key('player_buffering_spinner')))
              .bottom,
        ),
        reason: 'the label stands under the spinner',
      );
      expect(find.byKey(const Key('player_play_pause_button')), findsNothing);

      firstFrame.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('player_buffering_spinner')), findsNothing);
      expect(find.byKey(const Key('player_play_pause_button')), findsOneWidget);
    });

    testWidgets('show a notice with its action above the timeline', (
      tester,
    ) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      var actions = 0;
      await tester.pumpWidget(
        _wrapViewport(
          chrome: chrome(
            notice: PlayerNotice(
              message: 'Resumed from 2:22',
              actionLabel: 'Start over',
              onAction: () => actions++,
              onTimeout: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Resumed from 2:22'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      final notice = tester.getRect(find.byKey(const Key('player_notice')));
      final seekBar = tester.getRect(find.byKey(const Key('player_seek_bar')));
      expect(
        notice.left,
        moreOrLessEquals(seekBar.left),
        reason: 'in line with the timeline',
      );
      expect(notice.bottom, lessThan(seekBar.top));

      await tester.tap(find.byKey(const Key('player_notice_action')));
      expect(actions, 1);
    });

    testWidgets('keep the episodes with the buttons beside the timeline', (
      tester,
    ) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      late _FakePlatformPlayer platformPlayer;
      await tester.pumpWidget(
        _wrapViewport(
          playerBuilder: (configuration) {
            platformPlayer = _FakePlatformPlayer(configuration: configuration);
            return Player(platformPlayer: platformPlayer);
          },
          chrome: chrome(episodes: (context, close) => const SizedBox()),
        ),
      );
      await tester.pump();
      platformPlayer.emitDuration(const Duration(minutes: 24));
      platformPlayer.emitPosition(const Duration(seconds: 30));
      await _deliverPlayerEvent(tester);

      final episodes = find.byKey(const Key('player_episodes_button'));
      final tracks = find.byKey(const Key('player_tracks_button'));
      expect(tester.getSize(episodes), tester.getSize(tracks));
      expect(tester.getCenter(episodes).dy, tester.getCenter(tracks).dy);
      expect(
        tester.getCenter(episodes).dx,
        lessThan(tester.getCenter(tracks).dx),
      );
      expect(
        tester.getCenter(episodes).dy,
        greaterThan(TestWindowSizes.landscape.height / 2),
        reason: 'the episodes left the top bar',
      );
    });

    testWidgets('open the tracks above their button and keep the controls '
        'while open', (tester) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );
      await tester.pumpWidget(
        _wrapViewport(platformPlayer: platformPlayer, chrome: chrome()),
      );
      await tester.pump();
      platformPlayer.emitPlaying(true);
      await _deliverPlayerEvent(tester);
      final semantics = tester.ensureSemantics();
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.byKey(const Key('player_immersive_controls')),
          )
          .opacity;
      // The open panel hides the button from screen readers, so this asks
      // what the button says of itself.
      bool shownOpen() =>
          tester
              .widget<Semantics>(
                find.descendant(
                  of: find.byKey(const Key('player_tracks_button')),
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Semantics && widget.properties.button == true,
                  ),
                ),
              )
              .properties
              .selected ??
          false;

      final button = tester.getRect(
        find.byKey(const Key('player_tracks_button')),
      );
      await tester.tap(find.byKey(const Key('player_tracks_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final popover = tester.getRect(find.byKey(const Key('player_popover')));
      expect(popover.bottom, lessThan(button.top));
      expect(popover.right, moreOrLessEquals(button.right));
      expect(shownOpen(), isTrue, reason: 'its button shows it is open');

      // Long past the controls' idle time, they stay with the popover.
      await tester.pump(const Duration(seconds: 5));
      expect(opacity(), 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('player_popover')), findsNothing);
      expect(shownOpen(), isFalse);
      // Back in reach of screen readers, no longer selected.
      final readable = find.semantics.byLabel('Audio & subtitles').evaluate();
      expect(readable, contains(isSemantics(isButton: true)));
      expect(readable, everyElement(isNot(isSemantics(isSelected: true))));
      await tester.pump(const Duration(seconds: 3));
      expect(opacity(), 0);
      semantics.dispose();
    });

    testWidgets('light a glyph under the pointer and keep the focus with '
        'the player after a click', (tester) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      late _FakePlatformPlayer platformPlayer;
      await tester.pumpWidget(
        _wrapViewport(
          playerBuilder: (configuration) {
            platformPlayer = _FakePlatformPlayer(configuration: configuration);
            return Player(platformPlayer: platformPlayer);
          },
          chrome: chrome(),
        ),
      );
      await tester.pump();
      platformPlayer.emitDuration(const Duration(minutes: 24));
      await _deliverPlayerEvent(tester);

      final mute = find.byKey(const Key('player_mute_button'));
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.descendant(of: mute, matching: find.byType(AnimatedOpacity)),
          )
          .opacity;
      expect(opacity(), lessThan(1));
      expect(
        find.descendant(of: mute, matching: find.byType(InkWell)),
        findsNothing,
        reason: 'no Material circle behind the glyph',
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(mute));
      await tester.pump();
      expect(opacity(), 1);

      await tester.tap(mute);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player_immersive_controls',
      );
    });

    testWidgets('keep waiting on screen until the first frame, also when '
        'the file header already made playback ready', (tester) async {
      final firstFrameCompleter = Completer<void>();
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );
      await tester.pumpWidget(
        _wrapViewport(
          platformPlayer: platformPlayer,
          firstFrameFuture: firstFrameCompleter.future,
          chrome: chrome(),
        ),
      );
      await tester.pump();

      platformPlayer.emitDuration(const Duration(minutes: 24));
      platformPlayer.emitTracks(
        const Tracks(
          video: [
            VideoTrack('auto', null, null),
            VideoTrack('no', null, null),
            VideoTrack('1', 'Main Video', 'jpn'),
          ],
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('player_startup_label')), findsOneWidget);
      expect(find.byKey(const Key('player_buffering_spinner')), findsOneWidget);
      expect(find.byKey(const Key('player_play_pause_button')), findsNothing);

      firstFrameCompleter.complete();
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('player_startup_label')), findsNothing);
      expect(find.byKey(const Key('player_play_pause_button')), findsOneWidget);
    });

    testWidgets('switch the time left to the position and length on a '
        'click', (tester) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      late _FakePlatformPlayer platformPlayer;
      await tester.pumpWidget(
        _wrapViewport(
          playerBuilder: (configuration) {
            platformPlayer = _FakePlatformPlayer(configuration: configuration);
            return Player(platformPlayer: platformPlayer);
          },
          chrome: chrome(),
        ),
      );
      await tester.pump();
      platformPlayer.emitDuration(const Duration(minutes: 24));
      platformPlayer.emitPosition(const Duration(minutes: 4));
      await _deliverPlayerEvent(tester);

      String timeText() =>
          tester.widget<Text>(find.byKey(const Key('player_time_left'))).data!;
      expect(timeText(), '−20:00');

      await tester.tap(find.byKey(const Key('player_time_toggle')));
      await tester.pump();
      expect(timeText(), '4:00 / 24:00');

      await tester.tap(find.byKey(const Key('player_time_toggle')));
      await tester.pump();
      expect(timeText(), '−20:00');
    });

    testWidgets('show the stats only when asked for or when they explain '
        'a problem', (tester) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      final repository = _LateStatsPlayerRepository();
      await tester.pumpWidget(
        _wrapViewport(
          platformPlayer: _FakePlatformPlayer(
            configuration: const PlayerConfiguration(),
          ),
          firstFrameFuture: Future<void>.value(),
          repository: repository,
          chrome: chrome(),
        ),
      );
      await tester.pump();

      repository.emitStat(
        const PlayerPlaybackStats(
          downloadRateBytesPerSecond: 3 * 1024 * 1024,
          appMemoryBytes: null,
          activePeers: 8,
          bufferSeconds: 30,
          bufferPieces: 30,
          readaheadWindow: 30,
        ),
      );
      await tester.pump();
      expect(find.text('3.0 MB/s'), findsNothing);

      playerDetailedStatsEnabled.value = true;
      addTearDown(() => playerDetailedStatsEnabled.value = false);
      await tester.pump();
      expect(find.text('3.0 MB/s'), findsOneWidget);

      repository.finishCancel();
    });

    testWidgets('dim a paused frame', (tester) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      late _FakePlatformPlayer platformPlayer;
      await tester.pumpWidget(
        _wrapViewport(
          playerBuilder: (configuration) {
            platformPlayer = _FakePlatformPlayer(configuration: configuration);
            return Player(platformPlayer: platformPlayer);
          },
          chrome: chrome(),
        ),
      );
      await tester.pump();
      platformPlayer.emitDuration(const Duration(minutes: 24));
      await _deliverPlayerEvent(tester);

      double dim() => tester
          .widget<AnimatedOpacity>(find.byKey(const Key('player_pause_dim')))
          .opacity;
      platformPlayer.emitPlaying(true);
      await _deliverPlayerEvent(tester);
      expect(dim(), 0);

      platformPlayer.emitPlaying(false);
      await _deliverPlayerEvent(tester);
      expect(dim(), 1);
    });

    testWidgets('raise subtitles before the titles show and lower them '
        'after the titles hide', (tester) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );
      await tester.pumpWidget(
        _wrapViewport(platformPlayer: platformPlayer, chrome: chrome()),
      );
      await tester.pumpAndSettle();
      int subtitlePosition() =>
          int.parse(platformPlayer.nativeProperties['sub-pos']!);

      platformPlayer.emitPlaying(true);
      await _deliverPlayerEvent(tester);
      await tester.pump(const Duration(milliseconds: 300));
      final aboveBar = subtitlePosition();

      platformPlayer.emitPlaying(false);
      await _deliverPlayerEvent(tester);
      final aboveTitles = subtitlePosition();
      expect(aboveTitles, lessThan(aboveBar), reason: 'rises at once');

      platformPlayer.emitPlaying(true);
      await _deliverPlayerEvent(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(subtitlePosition(), aboveTitles, reason: 'titles still shown');
      await tester.pump(const Duration(milliseconds: 150));
      expect(subtitlePosition(), aboveBar);
    });

    testWidgets('show no hover tooltips', (tester) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_wrapViewport(chrome: chrome()));
      await tester.pump();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        tester.getCenter(find.byKey(const Key('player_seek_forward_button'))),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Forward 10 s'), findsNothing);
      expect(
        find.bySemanticsLabel('Forward 10 s'),
        findsOneWidget,
        reason: 'screen readers keep the label',
      );
      await mouse.removePointer();
      semantics.dispose();
    });

    testWidgets('show the titles only while paused', (tester) async {
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );
      await tester.pumpWidget(
        _wrapViewport(platformPlayer: platformPlayer, chrome: chrome()),
      );
      await tester.pump();
      expect(find.byKey(const Key('player_title_block')), findsOneWidget);

      platformPlayer.emitPlaying(true);
      await _deliverPlayerEvent(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('player_title_block')), findsNothing);
      expect(find.byKey(const Key('player_seek_bar')), findsOneWidget);

      platformPlayer.emitPlaying(false);
      await _deliverPlayerEvent(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('player_title_block')), findsOneWidget);
    });

    testWidgets('move subtitles drawn by mpv above the visible controls', (
      tester,
    ) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );
      await tester.pumpWidget(
        _wrapViewport(platformPlayer: platformPlayer, chrome: chrome()),
      );
      await tester.pump();
      // The height settles before the subtitles move.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      final lifted = int.parse(platformPlayer.nativeProperties['sub-pos']!);
      expect(lifted, lessThan(100));
      expect(lifted, greaterThan(50));

      platformPlayer.emitPlaying(true);
      await _deliverPlayerEvent(tester);
      await tester.pump(const Duration(seconds: 3));
      // They come down once the controls have faded.
      await tester.pump(const Duration(milliseconds: 250));
      expect(platformPlayer.nativeProperties['sub-pos'], '100');
    });

    testWidgets('move subtitles drawn by Flutter above the visible controls '
        'too', (tester) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      // Without libass, media_kit draws the subtitles in a SubtitleView.
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(libass: false),
      );
      await tester.pumpWidget(
        _wrapViewport(
          platformPlayer: platformPlayer,
          chrome: chrome(),
          realVideoSurface: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      double subtitleBottom() => tester
          .state<SubtitleViewState>(find.byType(SubtitleView))
          .padding
          .bottom;
      final seekBar = tester.getRect(find.byKey(const Key('player_seek_bar')));
      final view = tester.getRect(find.byType(SubtitleView));
      expect(
        view.bottom - subtitleBottom(),
        lessThanOrEqualTo(seekBar.top),
        reason: 'the subtitles stand above the timeline',
      );

      platformPlayer.emitPlaying(true);
      await _deliverPlayerEvent(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        subtitleBottom(),
        tester
            .widget<Video>(find.byType(Video))
            .subtitleViewConfiguration
            .padding
            .bottom,
        reason: 'they come down once the controls have faded',
      );
    });

    testWidgets('retry a failed start over visible controls, with no centre '
        'buttons, and the back button still works', (tester) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      final firstFrame = Completer<void>();
      late _FakePlatformPlayer platformPlayer;
      var backs = 0;
      await tester.pumpWidget(
        _wrapViewport(
          playerBuilder: (configuration) {
            platformPlayer = _FakePlatformPlayer(configuration: configuration);
            return Player(platformPlayer: platformPlayer);
          },
          firstFrameFuture: firstFrame.future,
          chrome: chrome(onBack: () => backs++),
        ),
      );
      await tester.pump();
      // Playing hides the controls after a few seconds; the pointer brings
      // them back over the failure.
      platformPlayer.emitPlaying(true);
      await _deliverPlayerEvent(tester);
      await tester.pump(const Duration(seconds: 4));
      firstFrame.completeError(StateError('no first frame'));
      await tester.pump();

      double controlsOpacity() => tester
          .widget<AnimatedOpacity>(
            find.byKey(const Key('player_immersive_controls')),
          )
          .opacity;
      expect(find.text('Unable to start playback.'), findsOneWidget);
      // mpv is paused behind the failure, so the controls come up with it.
      await _deliverPlayerEvent(tester);
      expect(controlsOpacity(), 1);

      expect(
        find.byKey(const Key('player_seek_backward_button')),
        findsNothing,
      );
      expect(find.byKey(const Key('player_play_pause_button')), findsNothing);
      expect(find.byKey(const Key('player_immersive_tap_layer')), findsNothing);
      expect(find.byKey(const Key('player_buffering_spinner')), findsNothing);

      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player_immersive_controls',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      expect(platformPlayer.playOrPauseCount, 0);

      expect(platformPlayer.openCount, 1);
      await tester.tap(find.widgetWithText(FilledButton, 'Try Again'));
      await tester.pump();
      expect(platformPlayer.openCount, 2, reason: 'retry opens the stream');

      await tester.tap(find.byKey(const Key('player_back_button')));
      expect(backs, 1);
    });
  });

  group('touch controls', () {
    const phone = Size(844, 390);
    PlayerChrome chrome({PlayerEpisodesBuilder? episodes}) => PlayerChrome(
      title: 'Episode 11',
      overline: 'Frieren',
      details: '[SubsPlease] Frieren · 11 of 28',
      onBack: () {},
      episodes: episodes,
    );
    double opacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.byKey(const Key('player_immersive_controls')),
        )
        .opacity;
    // Clear of the buttons: in the middle third, above play and ±10 s.
    final middle = Offset(phone.width / 2, 120);
    final left = Offset(phone.width * 0.2, 120);
    final right = Offset(phone.width * 0.8, 120);

    for (final size in const [phone, Size(1280, 800)]) {
      testWidgets('fit a ${size.width.toInt()}x${size.height.toInt()} screen '
          'with finger-sized buttons', (tester) async {
        setTestWindowSize(tester, size);
        await tester.pumpWidget(
          _wrapViewport(
            input: PlayerInputMode.touch,
            chrome: chrome(episodes: (context, close) => const SizedBox()),
            next: PlayerNextFile(title: 'Episode 12', play: () {}),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        for (final key in const [
          'player_back_button',
          'player_seek_backward_button',
          'player_seek_forward_button',
          'player_play_pause_button',
          'player_next_file_button',
          'player_episodes_button',
          'player_tracks_button',
          'player_settings_button',
        ]) {
          final button = tester.getRect(find.byKey(Key(key)));
          expect(button.width, greaterThanOrEqualTo(48), reason: key);
          expect(button.height, greaterThanOrEqualTo(48), reason: key);
          expect(button.left, greaterThanOrEqualTo(0), reason: key);
          expect(button.right, lessThanOrEqualTo(size.width), reason: key);
          expect(button.bottom, lessThanOrEqualTo(size.height), reason: key);
        }
        // The phone's own buttons and screen do these.
        expect(find.byKey(const Key('player_mute_button')), findsNothing);
        expect(find.byKey(const Key('player_fullscreen_button')), findsNothing);
      });
    }

    testWidgets('show and hide on a tap on the video, also while paused', (
      tester,
    ) async {
      setTestWindowSize(tester, phone);
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );
      await tester.pumpWidget(
        _wrapViewport(
          platformPlayer: platformPlayer,
          input: PlayerInputMode.touch,
          chrome: chrome(),
        ),
      );
      await tester.pump();
      expect(opacity(tester), 1, reason: 'paused');

      await tester.tapAt(middle);
      await tester.pump();
      expect(opacity(tester), 0, reason: 'hidden at once, though paused');
      expect(platformPlayer.playOrPauseCount, 0, reason: 'a tap only shows');

      await tester.tapAt(middle);
      await tester.pump();
      expect(opacity(tester), 1);

      platformPlayer.emitPlaying(true);
      await _deliverPlayerEvent(tester);
      await tester.pump(PlayerImmersiveControls.hideAfter);
      expect(opacity(tester), 0, reason: 'playing hides them');
      await tester.tapAt(middle);
      await tester.pump();
      expect(opacity(tester), 1);
    });

    testWidgets('stay a while longer after a touch on them', (tester) async {
      setTestWindowSize(tester, phone);
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );
      await tester.pumpWidget(
        _wrapViewport(
          platformPlayer: platformPlayer,
          input: PlayerInputMode.touch,
          chrome: chrome(),
        ),
      );
      await tester.pump();
      platformPlayer.emitPlaying(true);
      await _deliverPlayerEvent(tester);

      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byKey(const Key('player_time_toggle')));
      await tester.pump(const Duration(seconds: 2));
      expect(opacity(tester), 1, reason: 'the touch restarted the wait');

      await tester.pump(const Duration(milliseconds: 1100));
      expect(opacity(tester), 0);
    });

    testWidgets('stay while a finger drags along the timeline', (tester) async {
      setTestWindowSize(tester, phone);
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );
      await tester.pumpWidget(
        _wrapViewport(
          platformPlayer: platformPlayer,
          input: PlayerInputMode.touch,
          chrome: chrome(),
        ),
      );
      await tester.pump();
      platformPlayer.emitDuration(const Duration(minutes: 24));
      platformPlayer.emitPlaying(true);
      await _deliverPlayerEvent(tester);

      final drag = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('player_seek_bar'))),
      );
      await drag.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(seconds: 5));
      expect(opacity(tester), 1);

      await drag.up();
      await tester.pump(PlayerImmersiveControls.hideAfter);
      await tester.pump();
      expect(opacity(tester), 0);
    });

    testWidgets('leave full screen to the phone: no double tap, no F key', (
      tester,
    ) async {
      setTestWindowSize(tester, phone);
      var entered = 0;
      await tester.pumpWidget(
        _wrapViewport(
          input: PlayerInputMode.touch,
          chrome: chrome(),
          enterNativeFullscreen: () async => entered++,
        ),
      );
      await tester.pump();

      await tester.tapAt(middle);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(middle);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pump();

      expect(entered, 0);
    });

    testWidgets('keep clear of a camera cutout at the side', (tester) async {
      setTestWindowSize(tester, phone);
      tester.view.padding = const FakeViewPadding(left: 60, right: 30);
      await tester.pumpWidget(
        _wrapViewport(input: PlayerInputMode.touch, chrome: chrome()),
      );
      await tester.pump();

      expect(
        tester.getRect(find.byKey(const Key('player_back_button'))).left,
        greaterThanOrEqualTo(60),
      );
      expect(
        tester.getRect(find.byKey(const Key('player_seek_bar'))).left,
        greaterThanOrEqualTo(60 + 24),
      );
      expect(
        tester.getRect(find.byKey(const Key('player_settings_button'))).right,
        lessThanOrEqualTo(phone.width - 30),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('open the tracks as a popover of their button on a phone '
        'held sideways', (tester) async {
      setTestWindowSize(tester, phone);
      await tester.pumpWidget(
        _wrapViewport(input: PlayerInputMode.touch, chrome: chrome()),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('player_tracks_button')));
      await tester.pumpAndSettle();

      final popover = find.byKey(const Key('player_popover'));
      expect(
        find.descendant(
          of: popover,
          matching: find.byType(PlayerTrackSelectorSheet),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('change the speed from the settings', (tester) async {
      setTestWindowSize(tester, phone);
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );
      await tester.pumpWidget(
        _wrapViewport(
          platformPlayer: platformPlayer,
          input: PlayerInputMode.touch,
          chrome: chrome(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('player_settings_button')));
      await tester.pumpAndSettle();
      expect(find.text('Playback speed'), findsOneWidget);
      expect(find.text('SUBTITLE APPEARANCE'), findsOneWidget);

      await tester.tap(find.text('1.5×'));
      await tester.pump();
      expect(platformPlayer.rates, [1.5]);
    });

    testWidgets('close the open episodes on back before leaving', (
      tester,
    ) async {
      setTestWindowSize(tester, phone);
      var leaves = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') leaves++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        _wrapViewport(
          input: PlayerInputMode.touch,
          chrome: chrome(
            episodes: (context, close) => const Text('Episode list'),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('player_episodes_button')));
      await tester.pumpAndSettle();
      expect(find.text('Episode list'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Episode list'), findsNothing);
      expect(leaves, 0, reason: 'the player stays');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(leaves, 1);
    });

    Future<_FakePlatformPlayer> playerAt(
      WidgetTester tester, {
      List<BoxFit>? fits,
      bool playing = false,
    }) async {
      setTestWindowSize(tester, phone);
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );
      await tester.pumpWidget(
        _wrapViewport(
          platformPlayer: platformPlayer,
          input: PlayerInputMode.touch,
          chrome: chrome(),
          videoSurfaceBuilder:
              ({
                required controller,
                required subtitleViewConfiguration,
                required controls,
                required fit,
              }) {
                fits?.add(fit);
                return _videoSurface;
              },
        ),
      );
      await tester.pump();
      platformPlayer
        ..emitDuration(const Duration(minutes: 24))
        ..emitPosition(const Duration(minutes: 5));
      if (playing) platformPlayer.emitPlaying(true);
      await _deliverPlayerEvent(tester);
      return platformPlayer;
    }

    Finder plate(String key) => find.byKey(Key(key));

    testWidgets('seek 10 s on a double tap at a side and 10 s more on each '
        'tap after, from where the taps began', (tester) async {
      final platformPlayer = await playerAt(tester);

      await tester.tapAt(right);
      await tester.pump(const Duration(milliseconds: 100));
      expect(platformPlayer.seeks, isEmpty, reason: 'waits for a second tap');
      await tester.tapAt(right);
      await tester.pump();
      expect(platformPlayer.seeks, [const Duration(minutes: 5, seconds: 10)]);
      expect(
        find.descendant(
          of: plate('player_seek_streak_plate'),
          matching: find.text('+10'),
        ),
        findsOneWidget,
      );

      // The player has not caught up; the row still counts from 5:00.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tapAt(right);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tapAt(right);
      await tester.pump();
      expect(
        platformPlayer.seeks.last,
        const Duration(minutes: 5, seconds: 30),
      );
      expect(find.text('+30'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
      expect(plate('player_seek_streak_plate'), findsNothing);
      expect(opacity(tester), 1, reason: 'seeking left the controls alone');

      await tester.tapAt(left);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(left);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(left);
      await tester.pump();
      expect(
        platformPlayer.seeks.last,
        const Duration(minutes: 4, seconds: 40),
      );
      expect(find.text('−20'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('answer a tap in the middle at once and one at a side after '
        'the wait for a second', (tester) async {
      final platformPlayer = await playerAt(tester);

      await tester.tapAt(middle);
      await tester.pump();
      expect(opacity(tester), 0, reason: 'the middle never waits');

      await tester.tapAt(right);
      await tester.pump();
      expect(opacity(tester), 0, reason: 'a side waits for a second tap');
      await tester.pump(kDoubleTapTimeout);
      await tester.pump();
      expect(opacity(tester), 1);

      // Two taps in the middle show and hide; they never seek.
      await tester.tapAt(middle);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(middle);
      await tester.pump(const Duration(milliseconds: 400));
      expect(opacity(tester), 1);
      expect(platformPlayer.seeks, isEmpty);
    });

    testWidgets('leave the screen edges to the system', (tester) async {
      final platformPlayer = await playerAt(tester, playing: true);
      tester.view.systemGestureInsets = const FakeViewPadding(
        left: 30,
        right: 30,
      );
      await tester.pump();
      final edge = Offset(phone.width - 10, 120);

      await tester.tapAt(edge);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(edge);
      await tester.pump(const Duration(milliseconds: 400));
      expect(platformPlayer.seeks, isEmpty);
      expect(opacity(tester), 1, reason: 'not even shown or hidden');

      final press = await tester.startGesture(edge);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await press.up();
      await tester.pump();
      expect(platformPlayer.rates, isEmpty);
    });

    testWidgets('play at 2x while a long press holds, only during playback', (
      tester,
    ) async {
      final platformPlayer = await playerAt(tester);

      var press = await tester.startGesture(middle);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      expect(platformPlayer.rates, isEmpty, reason: 'paused');
      expect(plate('player_fast_forward_plate'), findsNothing);
      await press.up();
      await tester.pump();

      platformPlayer.emitPlaying(true);
      await _deliverPlayerEvent(tester);
      press = await tester.startGesture(middle);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      expect(platformPlayer.rates, [2]);
      expect(
        find.descendant(
          of: plate('player_fast_forward_plate'),
          matching: find.text('2×'),
        ),
        findsOneWidget,
      );

      await press.up();
      await tester.pump();
      expect(platformPlayer.rates, [2, 1]);
      expect(plate('player_fast_forward_plate'), findsNothing);
      expect(platformPlayer.seeks, isEmpty);
    });

    testWidgets('fill the screen on a pinch out and fit the video back on a '
        'pinch in', (tester) async {
      final fits = <BoxFit>[];
      await playerAt(tester, fits: fits);
      expect(fits.last, BoxFit.contain);

      await _pinch(tester, middle, from: 40, to: 90);
      expect(fits.last, BoxFit.cover);
      expect(find.text('Fill screen'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(plate('player_fit_plate'), findsNothing);

      await _pinch(tester, middle, from: 100, to: 40);
      expect(fits.last, BoxFit.contain);
      expect(find.text('Fit to screen'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('keep mpv subtitles on screen when a filled screen crops the '
        "video's bottom", (tester) async {
      final platformPlayer = await playerAt(tester, playing: true);
      platformPlayer.emitVideoSize(1920, 1080);
      await _deliverPlayerEvent(tester);
      await tester.pump(PlayerImmersiveControls.hideAfter);
      await tester.pump(const Duration(milliseconds: 250));
      expect(platformPlayer.nativeProperties['sub-pos'], '100');

      await _pinch(tester, middle, from: 40, to: 90);
      await tester.pump();
      // 16:9 across 844 dp is 475 dp tall: 42 dp of it below the screen.
      expect(platformPlayer.nativeProperties['sub-pos'], '91');

      await _pinch(tester, middle, from: 100, to: 40);
      await tester.pump();
      expect(platformPlayer.nativeProperties['sub-pos'], '100');
      await tester.pump(const Duration(seconds: 1));
    });
  });
}

const _videoSurface = ColoredBox(
  key: Key('player_video_surface'),
  color: Colors.black,
  child: SizedBox.expand(),
);

Widget _blackSurface({
  required VideoController controller,
  required SubtitleViewConfiguration subtitleViewConfiguration,
  required VideoControlsBuilder controls,
  required BoxFit fit,
}) {
  return _videoSurface;
}

const _nextPrompt = Key('player_next_file_prompt');
const _skipSegmentButton = Key('player_skip_segment_button');

/// Plays to 2:00, then the stream fails and mpv goes idle.
Future<_FakePlatformPlayer> _failMidStream(WidgetTester tester) async {
  final platformPlayer = _FakePlatformPlayer(
    configuration: const PlayerConfiguration(),
  );
  await tester.pumpWidget(_wrapViewport(platformPlayer: platformPlayer));
  await tester.pump();
  platformPlayer.emitPosition(const Duration(minutes: 2));
  await _deliverPlayerEvent(tester);
  platformPlayer
    ..emitError('tcp: Connection reset by peer')
    ..nativeProperties['idle-active'] = 'yes';
  await tester.pump(const Duration(seconds: 3));
  return platformPlayer;
}

/// Two fingers [from] dp either side of [centre] move to [to] dp.
Future<void> _pinch(
  WidgetTester tester,
  Offset centre, {
  required double from,
  required double to,
}) async {
  final first = await tester.startGesture(centre - Offset(from, 0));
  final second = await tester.startGesture(centre + Offset(from, 0));
  const steps = 5;
  final step = (to - from) / steps;
  for (var i = 0; i < steps; i++) {
    await first.moveBy(Offset(-step, 0));
    await second.moveBy(Offset(step, 0));
    await tester.pump();
  }
  await first.up();
  await second.up();
  await tester.pump();
}

/// The player's streams deliver after the next frame starts; the rebuild
/// they cause lands in the frame after.
Future<void> _deliverPlayerEvent(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

double _controlsOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(find.byKey(const Key('player_immersive_controls')))
    .opacity;

/// The time an offer has left, drawn while it counts down.
Finder _nextPromptCountdown() => find.byKey(const Key('player_countdown_bar'));

double _nextPromptOpacity(WidgetTester tester) {
  return tester
      .widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byKey(_nextPrompt),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;
}

Widget _wrapViewport({
  _FakePlatformPlayer? platformPlayer,
  Future<void>? firstFrameFuture,
  PlayerRepository? repository,
  PlayerSubtitlePreferencesCubit? subtitleCubit,
  PlayerDecodingPreferencesCubit? decodingCubit,
  MediaKitPlayerBuilder? playerBuilder,
  MediaKitVideoControllerBuilder? videoControllerBuilder,
  MediaKitVideoSurfaceBuilder? videoSurfaceBuilder,
  bool realVideoSurface = false,
  ValueChanged<MediaKitPlayerEngine>? onEngine,
  PlayerNextFile? next,
  PlayerChrome chrome = _plainChrome,
  PlayerInputMode input = PlayerInputMode.pointer,
  NativeFullscreenToggle? enterNativeFullscreen,
  NativeFullscreenToggle? exitNativeFullscreen,
  PlayerSession session = _session,
}) {
  final effectivePlatformPlayer =
      platformPlayer ??
      _FakePlatformPlayer(configuration: const PlayerConfiguration());
  final effectiveFirstFrameFuture = firstFrameFuture ?? Future<void>.value();
  final effectiveSubtitleCubit =
      subtitleCubit ??
      PlayerSubtitlePreferencesCubit(
        repository: MemorySubtitlePreferencesRepository(),
      );
  final effectiveDecodingCubit =
      decodingCubit ??
      PlayerDecodingPreferencesCubit(
        repository: MemoryDecodingPreferencesRepository(),
      );
  final factory = MediaKitPlayerViewportFactory(
    repository: repository ?? StubPlayerRepository(),
    enterNativeFullscreen: enterNativeFullscreen ?? () async {},
    exitNativeFullscreen: exitNativeFullscreen ?? () async {},
    playerBuilder:
        playerBuilder ??
        (configuration) => Player(platformPlayer: effectivePlatformPlayer),
    videoControllerBuilder:
        videoControllerBuilder ??
        (player, configuration) => _FakeVideoController(
          player: player,
          firstFrameFuture: effectiveFirstFrameFuture,
        ),
    // The app's own surface: media_kit's Video.
    videoSurfaceBuilder: realVideoSurface
        ? null
        : videoSurfaceBuilder ?? _blackSurface,
  );

  return testApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<PlayerSubtitlePreferencesCubit>.value(
          value: effectiveSubtitleCubit,
        ),
        BlocProvider<PlayerDecodingPreferencesCubit>.value(
          value: effectiveDecodingCubit,
        ),
      ],
      child: Scaffold(
        body: _EngineHost(
          factory: factory,
          subtitleCubit: effectiveSubtitleCubit,
          decodingCubit: effectiveDecodingCubit,
          session: session,
          onEngine: onEngine,
          next: next,
          chrome: chrome,
          input: input,
        ),
      ),
    ),
  );
}

void _stayOnPage() {}

const _plainChrome = PlayerChrome(title: 'Episode 11', onBack: _stayOnPage);

const _session = PlayerSession(
  sessionId: '42',
  streamUrl: 'http://127.0.0.1:8080/stream/2',
);

/// Owns the engine the way PlayerCubit does: opens it for [session] and
/// closes it when the page goes away.
class _EngineHost extends StatefulWidget {
  const _EngineHost({
    required this.factory,
    required this.subtitleCubit,
    required this.decodingCubit,
    this.session = _session,
    required this.chrome,
    required this.input,
    this.onEngine,
    this.next,
  });

  final MediaKitPlayerViewportFactory factory;
  final PlayerSession session;
  final PlayerSubtitlePreferencesCubit subtitleCubit;
  final PlayerDecodingPreferencesCubit decodingCubit;
  final ValueChanged<MediaKitPlayerEngine>? onEngine;
  final PlayerNextFile? next;
  final PlayerChrome chrome;
  final PlayerInputMode input;

  @override
  State<_EngineHost> createState() => _EngineHostState();
}

class _EngineHostState extends State<_EngineHost> {
  late final MediaKitPlayerEngine _engine = widget.factory.createEngine(
    subtitlePreferences: widget.subtitleCubit,
    decodingPreferences: widget.decodingCubit,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_engine.open(widget.session));
    widget.onEngine?.call(_engine);
  }

  @override
  void dispose() {
    unawaited(_engine.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.factory.build(
      engine: _engine,
      next: widget.next,
      chrome: widget.chrome,
      input: widget.input,
    );
  }
}

class _LateStatsPlayerRepository extends StubPlayerRepository {
  late final StreamController<PlayerPlaybackStats> _controller =
      StreamController<PlayerPlaybackStats>.broadcast(
        onCancel: () async {
          await _cancelCompleter.future;
        },
      );
  final _cancelCompleter = Completer<void>();

  void emitStat(PlayerPlaybackStats stats) {
    _controller.add(stats);
  }

  void finishCancel() {
    if (!_cancelCompleter.isCompleted) {
      _cancelCompleter.complete();
    }
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return _controller.stream;
  }
}

PlayerPlaybackStats _playbackStats({required int downloadRate}) {
  return PlayerPlaybackStats(
    downloadRateBytesPerSecond: downloadRate,
    appMemoryBytes: null,
    activePeers: 4,
    bufferSeconds: 10,
    bufferPieces: 12,
    readaheadWindow: 30,
  );
}

/// Hands out one stats stream per watch, as the data source does per stream
/// of a session.
class _SwitchingStatsPlayerRepository extends StubPlayerRepository {
  final watchedSessionIds = <String>[];
  final _streams = <StreamController<PlayerPlaybackStats>>[];

  void emit(int watch, PlayerPlaybackStats stats) {
    _streams[watch].add(stats);
  }

  Future<void> close() async {
    for (final stream in _streams) {
      await stream.close();
    }
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    watchedSessionIds.add(sessionId);
    final controller = StreamController<PlayerPlaybackStats>();
    _streams.add(controller);
    return controller.stream;
  }
}

class _FakePlatformPlayer extends PlatformPlayer {
  _FakePlatformPlayer({required super.configuration}) {
    completer.complete();
    videoControllerCompleter.complete();
  }

  final Map<String, String> nativeProperties = {};

  int openCount = 0;
  Playable? lastOpened;

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    openCount++;
    lastOpened = playable;
    nativeProperties['idle-active'] = 'no';
  }

  @override
  Future<void> stop() async {
    nativeProperties['idle-active'] = 'yes';
  }

  Future<void> setProperty(
    String key,
    String value, {
    bool waitForInitialization = true,
  }) async {
    nativeProperties[key] = value;
  }

  Future<String> getProperty(
    String property, {
    bool waitForInitialization = true,
  }) async {
    return nativeProperties[property] ?? '0';
  }

  void emitDuration(Duration duration) {
    state = state.copyWith(duration: duration);
    durationController.add(duration);
  }

  final seeks = <Duration>[];

  @override
  Future<void> seek(Duration duration) async {
    seeks.add(duration);
  }

  void emitPosition(Duration position) {
    state = state.copyWith(position: position);
    positionController.add(position);
  }

  void emitCompleted() {
    state = state.copyWith(completed: true);
    completedController.add(true);
  }

  /// An error line of mpv's log, as media_kit passes it on.
  void emitError(String text) => errorController.add(text);

  int pauseCount = 0;

  @override
  Future<void> pause() async {
    pauseCount++;
    emitPlaying(false);
  }

  void emitTracks(Tracks tracks) {
    state = state.copyWith(tracks: tracks);
    tracksController.add(tracks);
  }

  void emitVideoSize(int width, int height) {
    state = state.copyWith(width: width, height: height);
    widthController.add(width);
    heightController.add(height);
  }

  void emitPlaying(bool playing) {
    state = state.copyWith(playing: playing);
    playingController.add(playing);
  }

  int playOrPauseCount = 0;

  @override
  Future<void> playOrPause() async {
    playOrPauseCount++;
    emitPlaying(!state.playing);
  }

  final rates = <double>[];

  @override
  Future<void> setRate(double rate) async {
    rates.add(rate);
    state = state.copyWith(rate: rate);
    rateController.add(rate);
  }

  final volumes = <double>[];

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
    state = state.copyWith(volume: volume);
    volumeController.add(volume);
  }
}

class _ControllablePlatformPlayer extends _FakePlatformPlayer {
  _ControllablePlatformPlayer({
    required super.configuration,
    required this.openFuture,
  });

  final Future<void> openFuture;

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    await openFuture;
    await super.open(playable, play: play);
  }
}

class _FakeVideoController implements VideoController {
  _FakeVideoController({required this.player, required this.firstFrameFuture});

  @override
  final Player player;

  final Future<void> firstFrameFuture;

  @override
  final platform = Completer<PlatformVideoController>();

  @override
  final notifier = ValueNotifier<PlatformVideoController?>(null);

  @override
  final ValueNotifier<int?> id = ValueNotifier<int?>(null);

  @override
  final ValueNotifier<Rect?> rect = ValueNotifier<Rect?>(null);

  @override
  Future<void> setSize({int? width, int? height}) async {}

  @override
  Future<void> get waitUntilFirstFrameRendered async => firstFrameFuture;
}

/// mpv that never reports idle after a stop.
class _StuckPlatformPlayer extends _FakePlatformPlayer {
  _StuckPlatformPlayer({required super.configuration});

  bool disposed = false;

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    disposed = true;
    await super.dispose();
  }
}
