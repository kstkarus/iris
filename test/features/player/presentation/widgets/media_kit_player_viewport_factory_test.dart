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
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/features/player/presentation/widgets/player_overlay_preferences.dart';
import 'package:iris/features/player/presentation/widgets/player_track_selector_sheet.dart';
import 'package:iris/features/player/presentation/widgets/player_wait_indicator.dart';

import '../../../../helpers/fake_player_repository.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';
import '../../player_test_doubles.dart';

void main() {
  testWidgets(
    'keeps the track menu button available before and after viewport readiness',
    (tester) async {
      final firstFrameCompleter = Completer<void>();
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );

      await tester.pumpWidget(
        _wrapViewport(
          platformPlayer: platformPlayer,
          firstFrameFuture: firstFrameCompleter.future,
          videoSurfaceBuilder:
              ({
                required controller,
                required subtitleViewConfiguration,
                required controlsThemes,
              }) {
                return Column(
                  children: [
                    Row(children: controlsThemes.topButtonBar),
                    const Expanded(child: _videoSurface),
                  ],
                );
              },
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('player_track_selector_button')),
        findsOneWidget,
      );

      firstFrameCompleter.complete();
      await tester.pump();

      expect(
        find.byKey(const Key('player_track_selector_button')),
        findsOneWidget,
      );
    },
  );

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
    expect(
      find.byKey(const Key('player_viewport_loading_overlay')),
      findsOneWidget,
    );

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
    'keeps top stats visible after readiness even when controls keep the initial theme instance',
    (tester) async {
      final platformPlayer = _FakePlatformPlayer(
        configuration: const PlayerConfiguration(),
      );
      final repository = _LateStatsPlayerRepository();

      await tester.pumpWidget(
        _wrapViewport(
          platformPlayer: platformPlayer,
          firstFrameFuture: Future<void>.value(),
          repository: repository,
          videoSurfaceBuilder:
              ({
                required controller,
                required subtitleViewConfiguration,
                required controlsThemes,
              }) {
                return _StickyTopBarSurface(
                  topButtonBar: controlsThemes.topButtonBar,
                );
              },
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
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('player_track_selector_button')),
        findsOneWidget,
      );
      expect(find.text('0 B/s'), findsOneWidget);
      // Peers are a technical detail, hidden until the user turns it on.
      expect(find.text('0'), findsNothing);
      playerDetailedStatsEnabled.value = true;
      addTearDown(() => playerDetailedStatsEnabled.value = false);
      await tester.pump();
      expect(find.text('0'), findsOneWidget);

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
              required controlsThemes,
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

  testWidgets('offers the next file in the credits until the controls '
      'would hide', (tester) async {
    late _FakePlatformPlayer platformPlayer;

    await tester.pumpWidget(
      _wrapViewport(
        playerBuilder: (configuration) {
          platformPlayer = _FakePlatformPlayer(configuration: configuration);
          return Player(platformPlayer: platformPlayer);
        },
        next: PlayerNextFile(title: 'Episode 3', play: () {}),
        videoSurfaceBuilder: _pageLayerOnly,
      ),
    );
    await tester.pump();
    platformPlayer.emitDuration(const Duration(minutes: 24));
    platformPlayer.emitPosition(const Duration(minutes: 20));
    await _deliverPlayerEvent(tester);
    expect(find.byKey(_nextPrompt), findsNothing);

    platformPlayer.emitPosition(const Duration(minutes: 22));
    await _deliverPlayerEvent(tester);
    expect(find.text('Next episode'), findsOneWidget);
    expect(find.text('Episode 3'), findsOneWidget);
    expect(_nextPromptOpacity(tester), 1);

    // The countdown starts with the next frame.
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    expect(_nextPromptOpacity(tester), 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(const Offset(20, 20));
    await tester.pump();
    expect(_nextPromptOpacity(tester), 1);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(_nextPromptOpacity(tester), 0);

    platformPlayer.emitPosition(const Duration(minutes: 10));
    await _deliverPlayerEvent(tester);
    expect(find.byKey(_nextPrompt), findsNothing);
    await mouse.removePointer();
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

    await tester.pumpWidget(
      _wrapViewport(
        platformPlayer: platformPlayer,
        videoSurfaceBuilder: _pageLayerOnly,
      ),
    );
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
        videoSurfaceBuilder: _pageLayerOnly,
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
        videoSurfaceBuilder: _pageLayerOnly,
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

  testWidgets('keeps touch video controls on Android', (tester) async {
    MediaKitVideoControlsThemes? capturedThemes;

    await tester.pumpWidget(
      _wrapViewport(
        videoSurfaceBuilder:
            ({
              required controller,
              required subtitleViewConfiguration,
              required controlsThemes,
            }) {
              capturedThemes = controlsThemes;
              return _TopBarSurface(topButtonBar: controlsThemes.topButtonBar);
            },
      ),
    );
    await tester.pump();

    final themes = capturedThemes;
    expect(themes, isA<MediaKitMobileVideoControlsThemes>());
    final mobileThemes = themes! as MediaKitMobileVideoControlsThemes;
    expect(mobileThemes.normal.seekGesture, isTrue);
    expect(mobileThemes.normal.volumeGesture, isTrue);
    // Tracks and settings, each one tap away.
    expect(
      find.byKey(const Key('player_track_selector_button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('player_settings_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('player_settings_button')));
    await tester.pumpAndSettle();
    expect(find.text('SUBTITLE APPEARANCE'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('opens the track selector as a popover of its button on '
      'desktop', (tester) async {
    setTestWindowSize(tester, TestWindowSizes.landscape);
    await tester.pumpWidget(
      _wrapViewport(
        videoSurfaceBuilder:
            ({
              required controller,
              required subtitleViewConfiguration,
              required controlsThemes,
            }) {
              return _TopBarSurface(topButtonBar: controlsThemes.topButtonBar);
            },
      ),
    );
    await tester.pump();

    final button = tester.getRect(
      find.byKey(const Key('player_track_selector_button')),
    );
    await tester.tap(find.byKey(const Key('player_track_selector_button')));
    await tester.pumpAndSettle();

    final popover = find.byKey(const Key('player_popover'));
    expect(popover, findsOneWidget);
    expect(find.byKey(const Key('player_adaptive_sheet_dialog')), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      find.descendant(
        of: popover,
        matching: find.byType(PlayerTrackSelectorSheet),
      ),
      findsOneWidget,
    );
    // Its button names it.
    expect(find.text('Audio & subtitles'), findsNothing);
    // Out of the button at the top, ending in line with it at most and
    // clear of the window's edge.
    final rect = tester.getRect(popover);
    expect(rect.top, greaterThan(button.bottom));
    expect(rect.right, lessThanOrEqualTo(button.right + 0.5));
    expect(rect.right, lessThan(TestWindowSizes.landscape.width));
    // The video stays undimmed.
    expect(
      tester.widget<ModalBarrier>(find.byType(ModalBarrier).last).color,
      isNull,
    );

    await tester.tapAt(const Offset(40, 600));
    await tester.pumpAndSettle();
    expect(popover, findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('opens the track selector as a bottom sheet on compact phones', (
    tester,
  ) async {
    setTestWindowSize(tester, const Size(400, 800));

    await tester.pumpWidget(
      _wrapViewport(
        videoSurfaceBuilder:
            ({
              required controller,
              required subtitleViewConfiguration,
              required controlsThemes,
            }) {
              return _TopBarSurface(topButtonBar: controlsThemes.topButtonBar);
            },
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('player_track_selector_button')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('player_adaptive_sheet_dialog')), findsNothing);
  });

  testWidgets('sends the session headers with the stream', (tester) async {
    final platformPlayer = _FakePlatformPlayer(
      configuration: const PlayerConfiguration(),
    );
    await tester.pumpWidget(
      _wrapViewport(
        platformPlayer: platformPlayer,
        session: const PlayerSession(
          sessionId: '7',
          streamUrl: 'https://video.example/episode/1.m3u8',
          httpHeaders: {'Referer': 'https://player.example/'},
        ),
      ),
    );
    await tester.pump();

    final media = platformPlayer.lastOpened! as Media;
    expect(media.uri, 'https://video.example/episode/1.m3u8');
    expect(media.httpHeaders, {'Referer': 'https://player.example/'});
  });

  testWidgets('sends no headers for a torrent stream', (tester) async {
    final platformPlayer = _FakePlatformPlayer(
      configuration: const PlayerConfiguration(),
    );
    await tester.pumpWidget(_wrapViewport(platformPlayer: platformPlayer));
    await tester.pump();

    expect((platformPlayer.lastOpened! as Media).httpHeaders, isNull);
  });

  testWidgets('fits a 16:9 video frame into a wide window without overflow', (
    tester,
  ) async {
    setTestWindowSize(tester, const Size(1600, 700));

    await tester.pumpWidget(_wrapViewport());
    await tester.pump();

    expect(tester.takeException(), isNull);
    final videoSize = tester.getSize(
      find.byKey(const Key('player_video_surface')),
    );
    expect(videoSize.width / videoSize.height, closeTo(16 / 9, 0.01));
    expect(videoSize.height, lessThanOrEqualTo(700));
    expect(videoSize.width, lessThan(1600));
  });

  testWidgets('keeps a full-width 16:9 video frame on portrait phones', (
    tester,
  ) async {
    setTestWindowSize(tester, const Size(400, 800));

    await tester.pumpWidget(_wrapViewport());
    await tester.pump();

    expect(tester.takeException(), isNull);
    final videoSize = tester.getSize(
      find.byKey(const Key('player_video_surface')),
    );
    expect(videoSize.width, 400);
    expect(videoSize.height, closeTo(400 * 9 / 16, 0.01));
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
      MediaKitVideoControlsThemes? themes;

      await tester.pumpWidget(
        _wrapViewport(
          chrome: chrome(onBack: () => backs++),
          videoSurfaceBuilder:
              ({
                required controller,
                required subtitleViewConfiguration,
                required controlsThemes,
              }) {
                themes = controlsThemes;
                return _videoSurface;
              },
        ),
      );
      await tester.pump();

      expect(themes, isA<MediaKitImmersiveVideoControlsThemes>());
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
}

class _TopBarSurface extends StatelessWidget {
  const _TopBarSurface({required this.topButtonBar});

  final List<Widget> topButtonBar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 56, child: Row(children: topButtonBar)),
        const Expanded(child: _videoSurface),
      ],
    );
  }
}

const _videoSurface = ColoredBox(
  key: Key('player_video_surface'),
  color: Colors.black,
  child: SizedBox.expand(),
);

Widget _blackSurface({
  required VideoController controller,
  required SubtitleViewConfiguration subtitleViewConfiguration,
  required MediaKitVideoControlsThemes controlsThemes,
}) {
  return _videoSurface;
}

const _nextPrompt = Key('player_next_file_prompt');
const _skipSegmentButton = Key('player_skip_segment_button');

/// Renders only the page's layer over the media_kit controls.
Widget _pageLayerOnly({
  required VideoController controller,
  required SubtitleViewConfiguration subtitleViewConfiguration,
  required MediaKitVideoControlsThemes controlsThemes,
}) {
  return controlsThemes.decorateControls!(
    VideoState(),
    const SizedBox.expand(),
  );
}

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

/// The player's streams deliver after the next frame starts; the rebuild
/// they cause lands in the frame after.
Future<void> _deliverPlayerEvent(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

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
  PlayerChrome? chrome,
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
        ),
      ),
    ),
  );
}

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
    this.onEngine,
    this.next,
    this.chrome,
  });

  final MediaKitPlayerViewportFactory factory;
  final PlayerSession session;
  final PlayerSubtitlePreferencesCubit subtitleCubit;
  final PlayerDecodingPreferencesCubit decodingCubit;
  final ValueChanged<MediaKitPlayerEngine>? onEngine;
  final PlayerNextFile? next;
  final PlayerChrome? chrome;

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

class _StickyTopBarSurface extends StatefulWidget {
  const _StickyTopBarSurface({required this.topButtonBar});

  final List<Widget> topButtonBar;

  @override
  State<_StickyTopBarSurface> createState() => _StickyTopBarSurfaceState();
}

class _StickyTopBarSurfaceState extends State<_StickyTopBarSurface> {
  late final List<Widget> _initialTopButtonBar = List<Widget>.from(
    widget.topButtonBar,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: _initialTopButtonBar),
        const Expanded(child: _videoSurface),
      ],
    );
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
