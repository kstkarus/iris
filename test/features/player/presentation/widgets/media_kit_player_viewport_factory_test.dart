import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/domain/repositories/player_decoding_preferences_repository.dart';
import 'package:iris/features/player/domain/repositories/subtitle_preferences_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/playback/media_kit_player_engine.dart';
import 'package:iris/features/player/presentation/widgets/media_kit_player_viewport_factory.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/features/player/presentation/widgets/player_overlay_preferences.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

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
                    const Expanded(
                      child: ColoredBox(
                        key: Key('player_video_surface'),
                        color: Colors.black,
                        child: SizedBox.expand(),
                      ),
                    ),
                  ],
                );
              },
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.tune), findsOneWidget);

      firstFrameCompleter.complete();
      await tester.pump();

      expect(find.byIcon(Icons.tune), findsOneWidget);
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

      expect(find.text('Buffering...'), findsAtLeastNWidgets(1));
      expect(find.byKey(const Key('player_video_surface')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      firstFrameCompleter.complete();
      await tester.pump();

      expect(find.text('Buffering...'), findsNothing);
    },
  );

  testWidgets(
    'marks viewport ready when duration and a real video track are discovered before the first frame',
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

      expect(find.text('Buffering...'), findsNothing);
    },
  );

  testWidgets(
    'shows a dedicated error when media_kit does not prepare the first frame in time',
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
      await tester.pump(const Duration(seconds: 46));

      expect(
        find.text(
          'The stream is open, but the player could not prepare the first frame.',
        ),
        findsOneWidget,
      );
      expect(find.text('Try Again'), findsOneWidget);
    },
  );

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

      expect(find.text('Buffering...'), findsOneWidget);
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

      expect(find.byIcon(Icons.tune), findsOneWidget);
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
    'fails startup early when playback stats show no network activity',
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
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 16));

      expect(find.text('Unable to start playback.'), findsOneWidget);

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
        repository: const _FakeSubtitlePreferencesRepository(),
      );
      final slowOpenCompleter = Completer<void>();
      final createdPlayers = <_ControllablePlatformPlayer>[];

      await tester.pumpWidget(
        _wrapViewport(
          repository: const _FakePlayerRepository(),
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
        repository: const _FakePlayerDecodingPreferencesRepository(
          PlayerDecodingPreferences(
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
              return const ColoredBox(
                key: Key('player_video_surface'),
                color: Colors.black,
                child: SizedBox.expand(),
              );
            },
      ),
    );
    await tester.pump();
    expect(find.text('Buffering...'), findsNothing);

    await tester.runAsync(engine.stop);
    await tester.pump();
    expect(find.text('Preparing video...'), findsAtLeastNWidgets(1));
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
    expect(find.text('Buffering...'), findsNothing);
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

    await tester.pump(const Duration(seconds: 8));
    expect(_nextPromptOpacity(tester), 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(const Offset(20, 20));
    await tester.pump();
    expect(_nextPromptOpacity(tester), 1);
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

  testWidgets('uses desktop video controls on Windows', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
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
                return _TopBarSurface(
                  topButtonBar: controlsThemes.topButtonBar,
                );
              },
        ),
      );
      await tester.pump();

      final themes = capturedThemes;
      expect(themes, isA<MediaKitDesktopVideoControlsThemes>());
      expect(themes!.controlsBuilder, same(MaterialDesktopVideoControls));
      final desktopThemes = themes as MediaKitDesktopVideoControlsThemes;
      expect(desktopThemes.normal.toggleFullscreenOnDoublePress, isTrue);
      expect(desktopThemes.normal.keyboardShortcuts, isNull);
      expect(
        desktopThemes.normal.bottomButtonBar
            .whereType<MaterialDesktopFullscreenButton>(),
        isNotEmpty,
      );
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.byType(MaterialDesktopCustomButton), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('keeps touch video controls on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
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
                return _TopBarSurface(
                  topButtonBar: controlsThemes.topButtonBar,
                );
              },
        ),
      );
      await tester.pump();

      final themes = capturedThemes;
      expect(themes, isA<MediaKitMobileVideoControlsThemes>());
      expect(themes!.controlsBuilder, same(MaterialVideoControls));
      final mobileThemes = themes as MediaKitMobileVideoControlsThemes;
      expect(mobileThemes.normal.seekGesture, isTrue);
      expect(mobileThemes.normal.volumeGesture, isTrue);
      expect(find.byType(MaterialCustomButton), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('opens the track selector as a dialog on desktop', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        _wrapViewport(
          videoSurfaceBuilder:
              ({
                required controller,
                required subtitleViewConfiguration,
                required controlsThemes,
              }) {
                return _TopBarSurface(
                  topButtonBar: controlsThemes.topButtonBar,
                );
              },
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('player_adaptive_sheet_dialog')),
        findsOneWidget,
      );
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Playback Tracks'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('opens the track selector as a bottom sheet on compact phones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('player_adaptive_sheet_dialog')), findsNothing);
  });

  testWidgets('fits a 16:9 video frame into a wide window without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrapViewport());
    await tester.pump();

    expect(tester.takeException(), isNull);
    final videoSize = tester.getSize(
      find.byKey(const Key('player_video_surface')),
    );
    expect(videoSize.width, 400);
    expect(videoSize.height, closeTo(400 * 9 / 16, 0.01));
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
        const Expanded(
          child: ColoredBox(
            key: Key('player_video_surface'),
            color: Colors.black,
            child: SizedBox.expand(),
          ),
        ),
      ],
    );
  }
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
  PlayerRepository repository = const _FakePlayerRepository(),
  PlayerSubtitlePreferencesCubit? subtitleCubit,
  PlayerDecodingPreferencesCubit? decodingCubit,
  MediaKitPlayerBuilder? playerBuilder,
  MediaKitVideoControllerBuilder? videoControllerBuilder,
  MediaKitVideoSurfaceBuilder? videoSurfaceBuilder,
  ValueChanged<MediaKitPlayerEngine>? onEngine,
  PlayerNextFile? next,
}) {
  final effectivePlatformPlayer =
      platformPlayer ??
      _FakePlatformPlayer(configuration: const PlayerConfiguration());
  final effectiveFirstFrameFuture = firstFrameFuture ?? Future<void>.value();
  final effectiveSubtitleCubit =
      subtitleCubit ??
      PlayerSubtitlePreferencesCubit(
        repository: const _FakeSubtitlePreferencesRepository(),
      );
  final effectiveDecodingCubit =
      decodingCubit ??
      PlayerDecodingPreferencesCubit(
        repository: const _FakePlayerDecodingPreferencesRepository(
          PlayerDecodingPreferences.defaults(),
        ),
      );
  final factory = MediaKitPlayerViewportFactory(
    repository: repository,
    playerBuilder:
        playerBuilder ??
        (configuration) => Player(platformPlayer: effectivePlatformPlayer),
    videoControllerBuilder:
        videoControllerBuilder ??
        (player, configuration) => _FakeVideoController(
          player: player,
          firstFrameFuture: effectiveFirstFrameFuture,
        ),
    videoSurfaceBuilder:
        videoSurfaceBuilder ??
        ({
          required controller,
          required subtitleViewConfiguration,
          required controlsThemes,
        }) {
          return const ColoredBox(
            key: Key('player_video_surface'),
            color: Colors.black,
            child: SizedBox.expand(),
          );
        },
  );

  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
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
          onEngine: onEngine,
          next: next,
        ),
      ),
    ),
  );
}

const _session = PlayerSession(
  sessionId: '42',
  streamUrl: 'http://127.0.0.1:8080/stream/2',
);

/// Owns the engine the way PlayerCubit does: opens it for [_session] and
/// closes it when the page goes away.
class _EngineHost extends StatefulWidget {
  const _EngineHost({
    required this.factory,
    required this.subtitleCubit,
    required this.decodingCubit,
    this.onEngine,
    this.next,
  });

  final MediaKitPlayerViewportFactory factory;
  final PlayerSubtitlePreferencesCubit subtitleCubit;
  final PlayerDecodingPreferencesCubit decodingCubit;
  final ValueChanged<MediaKitPlayerEngine>? onEngine;
  final PlayerNextFile? next;

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
    unawaited(_engine.open(_session));
    widget.onEngine?.call(_engine);
  }

  @override
  void dispose() {
    unawaited(_engine.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.factory.build(engine: _engine, next: widget.next);
  }
}

class _FakePlayerRepository implements PlayerRepository {
  @override
  Future<void> stopPlayback({required String sessionId}) async {}

  const _FakePlayerRepository();

  @override
  Future<void> disposePlayback({required String sessionId}) async {}

  @override
  Future<PreparedPlayerSource> prepareSource({required String magnet}) {
    throw UnimplementedError();
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

class _LateStatsPlayerRepository implements PlayerRepository {
  @override
  Future<void> stopPlayback({required String sessionId}) async {}

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
  Future<void> disposePlayback({required String sessionId}) async {}

  @override
  Future<PreparedPlayerSource> prepareSource({required String magnet}) {
    throw UnimplementedError();
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
    return _controller.stream;
  }
}

class _FakeSubtitlePreferencesRepository
    implements SubtitlePreferencesRepository {
  const _FakeSubtitlePreferencesRepository();

  @override
  Future<SubtitlePreferences> loadPreferences() async {
    return const SubtitlePreferences.defaults();
  }

  @override
  Future<void> savePreferences(SubtitlePreferences preferences) async {}
}

class _FakePlayerDecodingPreferencesRepository
    implements PlayerDecodingPreferencesRepository {
  const _FakePlayerDecodingPreferencesRepository(this.preferences);

  final PlayerDecodingPreferences preferences;

  @override
  Future<PlayerDecodingPreferences> loadPreferences() async {
    return preferences;
  }

  @override
  Future<void> savePreferences(PlayerDecodingPreferences preferences) async {}
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
        const Expanded(
          child: ColoredBox(
            key: Key('player_video_surface'),
            color: Colors.black,
            child: SizedBox.expand(),
          ),
        ),
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

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    openCount++;
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

  void emitTracks(Tracks tracks) {
    state = state.copyWith(tracks: tracks);
    tracksController.add(tracks);
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
