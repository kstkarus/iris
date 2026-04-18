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

  testWidgets('ignores late playback stats after viewport disposal starts', (
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
          videoControllerBuilder: (player) => _FakeVideoController(
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
}

Widget _wrapViewport({
  _FakePlatformPlayer? platformPlayer,
  Future<void>? firstFrameFuture,
  PlayerRepository repository = const _FakePlayerRepository(),
  PlayerSubtitlePreferencesCubit? subtitleCubit,
  MediaKitPlayerBuilder? playerBuilder,
  MediaKitVideoControllerBuilder? videoControllerBuilder,
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
  final factory = MediaKitPlayerViewportFactory(
    repository: repository,
    playerBuilder:
        playerBuilder ??
        (configuration) => Player(platformPlayer: effectivePlatformPlayer),
    videoControllerBuilder:
        videoControllerBuilder ??
        (player) => _FakeVideoController(
          player: player,
          firstFrameFuture: effectiveFirstFrameFuture,
        ),
    videoSurfaceBuilder:
        ({
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
    home: BlocProvider<PlayerSubtitlePreferencesCubit>.value(
      value: effectiveSubtitleCubit,
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

class _LateStatsPlayerRepository implements PlayerRepository {
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

class _ControllablePlatformPlayer extends _FakePlatformPlayer {
  _ControllablePlatformPlayer({
    required super.configuration,
    required this.openFuture,
  });

  final Future<void> openFuture;

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    await openFuture;
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
