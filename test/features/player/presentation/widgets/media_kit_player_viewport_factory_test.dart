import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/domain/repositories/subtitle_preferences_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/widgets/media_kit_player_viewport_factory.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
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

      expect(find.text('Buffering...'), findsOneWidget);
      expect(find.byKey(const Key('player_video_surface')), findsOneWidget);

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
}

Widget _wrapViewport({
  required _FakePlatformPlayer platformPlayer,
  required Future<void> firstFrameFuture,
}) {
  final factory = MediaKitPlayerViewportFactory(
    repository: const _FakePlayerRepository(),
    playerBuilder: (configuration) => Player(platformPlayer: platformPlayer),
    videoControllerBuilder: (player) =>
        _FakeVideoController(player: player, firstFrameFuture: firstFrameFuture),
    videoSurfaceBuilder: ({
      required controller,
      required subtitleViewConfiguration,
      required normalTheme,
      required fullscreenTheme,
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
    home: BlocProvider(
      create: (_) => PlayerSubtitlePreferencesCubit(
        repository: const _FakeSubtitlePreferencesRepository(),
      ),
      child: Scaffold(
        body: factory.build(
          source: _source,
          session: const PlayerSession(
            sessionId: '42',
            streamUrl: 'http://127.0.0.1:8080/stream/2',
          ),
        ),
      ),
    ),
  );
}

class _FakePlayerRepository implements PlayerRepository {
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

class _FakePlatformPlayer extends PlatformPlayer {
  _FakePlatformPlayer({required super.configuration}) {
    completer.complete();
    videoControllerCompleter.complete();
  }

  final Map<String, String> nativeProperties = {};

  @override
  Future<void> open(Playable playable, {bool play = true}) async {}

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

  void emitTracks(Tracks tracks) {
    state = state.copyWith(tracks: tracks);
    tracksController.add(tracks);
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

const _source = AnimePlayerSource(
  animeId: '32281',
  animeTitle: 'Kimi no Na wa.',
  sourceTitle: '[Mock] Movie Source',
  sessionId: '42',
  fileIndex: 0,
  fileName: 'kimi-no-na-wa.mkv',
);
