import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_launch_progress.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/pages/player_page.dart';
import 'package:iris/features/player/presentation/playback/player_engine.dart';
import 'package:iris/features/player/presentation/widgets/player_adaptive_layout.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

import '../../../../helpers/fake_player_engine.dart';

void main() {
  void setWindow(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('titles the app bar with the episode and the release', (
    tester,
  ) async {
    setWindow(tester, const Size(400, 800));

    await tester.pumpWidget(_wrap());

    final appBar = find.byType(AppBar);
    expect(
      find.descendant(of: appBar, matching: find.text('episode-02')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: appBar, matching: find.text(_source.sourceTitle)),
      findsOneWidget,
    );
    expect(find.text('Iris'), findsNothing);
    expect(find.text('Player'), findsNothing);
    expect(find.byKey(const Key('player_video_surface')), findsOneWidget);
  });

  testWidgets('lists episodes below the video on phones', (tester) async {
    setWindow(tester, const Size(400, 800));

    await tester.pumpWidget(_wrap(source: _seriesSource));

    final video = tester.getRect(find.byKey(const Key('player_video_surface')));
    final pane = tester.getRect(find.byKey(PlayerPage.episodesPaneKey));
    expect(pane.top, greaterThanOrEqualTo(video.bottom));
    expect(find.byKey(PlayerPage.episodesToggleKey), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.text('Now playing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a hideable episodes pane beside the video on wide '
      'windows', (tester) async {
    setWindow(tester, const Size(1280, 720));

    await tester.pumpWidget(_wrap(source: _seriesSource));

    final video = tester.getRect(find.byKey(const Key('player_video_surface')));
    final pane = tester.getRect(find.byKey(PlayerPage.episodesPaneKey));
    expect(pane.left, greaterThanOrEqualTo(video.right));
    expect(pane.width, inInclusiveRange(280, 420));
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('player_episode_2')))
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(PlayerPage.episodesToggleKey));
    await tester.pumpAndSettle();
    expect(find.byKey(PlayerPage.episodesPaneKey), findsNothing);

    await tester.tap(find.byKey(PlayerPage.episodesToggleKey));
    await tester.pumpAndSettle();
    expect(find.byKey(PlayerPage.episodesPaneKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the video alive when the layout switches', (tester) async {
    setWindow(tester, const Size(1280, 720));
    await tester.pumpWidget(_wrap(source: _seriesSource));
    final before = tester.state(find.byKey(const Key('player_video_surface')));

    setWindow(tester, const Size(400, 800));
    await tester.pump();

    expect(
      tester.state(find.byKey(const Key('player_video_surface'))),
      same(before),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('announces an automatic resume with a Start over action', (
    tester,
  ) async {
    setWindow(tester, const Size(1280, 720));

    await tester.pumpWidget(_wrap());
    // The page reacts to the launch finishing, not to its initial state.
    (tester.element(find.byType(PlayerPage)).read<PlayerCubit>()
            as _FakePlayerCubit)
        .push(
          const PlayerReady(
            PlayerSession(sessionId: '42', streamUrl: 'http://127.0.0.1/2'),
            startPosition: Duration(minutes: 12, seconds: 34),
            showResumeNotice: true,
          ),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Resumed from 12:34'), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, 'Start over'), findsOneWidget);

    // Its action belongs to that file: switching files closes it.
    (tester.element(find.byType(PlayerPage)).read<PlayerCubit>()
            as _FakePlayerCubit)
        .push(const PlayerPreparing(progress: PlayerLaunchProgress.initial()));
    // The loading spinner never settles; let the snackbar animate out.
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Resumed from 12:34'), findsNothing);
  });

  test('detects desktop platforms', () {
    expect(isDesktopPlayerPlatform(TargetPlatform.windows), isTrue);
    expect(isDesktopPlayerPlatform(TargetPlatform.linux), isTrue);
    expect(isDesktopPlayerPlatform(TargetPlatform.macOS), isTrue);
    expect(isDesktopPlayerPlatform(TargetPlatform.android), isFalse);
    expect(isDesktopPlayerPlatform(TargetPlatform.iOS), isFalse);
  });
}

Widget _wrap({
  AnimePlayerSource source = _source,
  PlayerState state = const PlayerReady(
    PlayerSession(sessionId: '42', streamUrl: 'http://127.0.0.1:8080/stream/2'),
  ),
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<PlayerCubit>(
      create: (_) => _FakePlayerCubit(source, state),
      child: const PlayerPage(viewportFactory: _FakeViewportFactory()),
    ),
  );
}

class _FakePlayerCubit extends PlayerCubit {
  _FakePlayerCubit(AnimePlayerSource source, PlayerState initialState)
    : super(
        source: source,
        repository: _UnusedPlayerRepository(),
        engine: FakePlayerEngine(),
      ) {
    emit(initialState);
  }

  void push(PlayerState next) => emit(next);

  @override
  Future<void> loadPlayback() async {}
}

class _UnusedPlayerRepository implements PlayerRepository {
  @override
  Future<void> stopPlayback({required String sessionId}) async {}

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

class _FakeViewportFactory implements PlayerViewportFactory {
  const _FakeViewportFactory();

  @override
  PlayerEngine createEngine({
    required PlayerSubtitlePreferencesCubit subtitlePreferences,
    required PlayerDecodingPreferencesCubit decodingPreferences,
  }) {
    return FakePlayerEngine();
  }

  @override
  Widget build({required PlayerEngine engine, PlayerNextFile? next}) {
    return const _FakeVideoSurface(key: Key('player_video_surface'));
  }
}

/// Stateful so tests can tell a kept surface from a recreated one.
class _FakeVideoSurface extends StatefulWidget {
  const _FakeVideoSurface({super.key});

  @override
  State<_FakeVideoSurface> createState() => _FakeVideoSurfaceState();
}

class _FakeVideoSurfaceState extends State<_FakeVideoSurface> {
  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black, child: SizedBox.expand());
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

const _seriesSource = AnimePlayerSource(
  animeId: '5114',
  animeTitle: 'Fullmetal Alchemist: Brotherhood',
  sourceTitle: '[Mock] Fullmetal Alchemist: Brotherhood Batch',
  sessionId: '42',
  fileIndex: 2,
  fileName: 'episode-02.mkv',
  files: [
    PlayerVideoFile(
      index: 1,
      name: 'episode-01.mkv',
      size: 1,
      extension: 'mkv',
    ),
    PlayerVideoFile(
      index: 2,
      name: 'episode-02.mkv',
      size: 1,
      extension: 'mkv',
    ),
    PlayerVideoFile(
      index: 3,
      name: 'episode-03.mkv',
      size: 1,
      extension: 'mkv',
    ),
  ],
);
