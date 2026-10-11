import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/entities/user_rate/data/mock_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/mark_episode_watched.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/player/presentation/cubit/episode_mark_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';
import 'package:iris/features/player/presentation/pages/player_page.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';
import '../../player_test_doubles.dart';

void main() {
  testWidgets('titles the app bar with the episode and the release', (
    tester,
  ) async {
    setTestWindowSize(tester, const Size(400, 800));

    await tester.pumpWidget(_wrap());

    final appBar = find.byType(AppBar);
    expect(
      find.descendant(of: appBar, matching: find.text('episode-02')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: appBar,
        matching: find.text(fmaPlayerSource.sourceTitle),
      ),
      findsOneWidget,
    );
    expect(find.text('Iris'), findsNothing);
    expect(find.text('Player'), findsNothing);
    expect(find.byKey(const Key('player_video_surface')), findsOneWidget);
  });

  testWidgets('lists episodes below the video on phones', (tester) async {
    setTestWindowSize(tester, const Size(400, 800));

    await tester.pumpWidget(_wrap(source: _seriesSource));

    final video = tester.getRect(find.byKey(const Key('player_video_surface')));
    final pane = tester.getRect(find.byKey(PlayerPage.episodesPaneKey));
    expect(pane.top, greaterThanOrEqualTo(video.bottom));
    expect(find.byKey(PlayerPage.episodesToggleKey), findsNothing);
    expect(find.byKey(const Key('player_episodes_close_button')), findsNothing);
    expect(find.text('NOW PLAYING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a hideable episodes pane beside the video on wide '
      'windows', (tester) async {
    setTestWindowSize(tester, TestWindowSizes.landscape);

    await tester.pumpWidget(_wrap(source: _seriesSource));

    final video = tester.getRect(find.byKey(const Key('player_video_surface')));
    final pane = tester.getRect(find.byKey(PlayerPage.episodesPaneKey));
    expect(pane.left, greaterThanOrEqualTo(video.right));
    expect(pane.width, inInclusiveRange(280, 420));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('player_episode_2')),
        matching: find.text('NOW PLAYING'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(PlayerPage.episodesToggleKey));
    await tester.pumpAndSettle();
    expect(find.byKey(PlayerPage.episodesPaneKey), findsNothing);

    await tester.tap(find.byKey(PlayerPage.episodesToggleKey));
    await tester.pumpAndSettle();
    expect(find.byKey(PlayerPage.episodesPaneKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('in short windows', () {
    testWidgets('gives the video the full height of a compact landscape '
        'window, with the episodes behind the toggle', (tester) async {
      setTestWindowSize(tester, const Size(500, 300));

      await tester.pumpWidget(_wrap(source: _seriesSource));

      expect(tester.takeException(), isNull);
      // The window less the app bar and the video's own margins.
      final video = tester.getRect(
        find.byKey(const Key('player_video_surface')),
      );
      expect(video.height, closeTo(220, 0.5));
      expect(find.byKey(PlayerPage.episodesPaneKey), findsNothing);

      await tester.tap(find.byKey(PlayerPage.episodesToggleKey));
      await tester.pumpAndSettle();

      final shownVideo = tester.getRect(
        find.byKey(const Key('player_video_surface')),
      );
      final pane = tester.getRect(find.byKey(PlayerPage.episodesPaneKey));
      expect(pane.left, greaterThanOrEqualTo(shownVideo.right));
      expect(find.text('NOW PLAYING'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the episodes beside the video on a 640x360 phone', (
      tester,
    ) async {
      setTestWindowSize(tester, const Size(640, 360));

      await tester.pumpWidget(_wrap(source: _seriesSource));

      final video = tester.getRect(
        find.byKey(const Key('player_video_surface')),
      );
      final pane = tester.getRect(find.byKey(PlayerPage.episodesPaneKey));
      expect(pane.left, greaterThanOrEqualTo(video.right));
      expect(video.height, closeTo(272, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps a 16:9 video full width on a 360x640 phone, with the '
        'episodes below', (tester) async {
      setTestWindowSize(tester, const Size(360, 640));

      await tester.pumpWidget(_wrap(source: _seriesSource));

      final video = tester.getRect(
        find.byKey(const Key('player_video_surface')),
      );
      final pane = tester.getRect(find.byKey(PlayerPage.episodesPaneKey));
      expect(video.width, closeTo(328, 0.5));
      expect(video.height, closeTo(328 * 9 / 16, 0.5));
      expect(pane.top, greaterThanOrEqualTo(video.bottom));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('keeps the video alive when the layout switches', (tester) async {
    setTestWindowSize(tester, TestWindowSizes.landscape);
    await tester.pumpWidget(_wrap(source: _seriesSource));
    final before = tester.state(find.byKey(const Key('player_video_surface')));

    setTestWindowSize(tester, const Size(400, 800));
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
    setTestWindowSize(tester, TestWindowSizes.landscape);

    await tester.pumpWidget(_wrap());
    // The page reacts to the launch finishing, not to its initial state.
    (tester.element(find.byType(PlayerPage)).read<PlayerCubit>()
            as FakePlayerCubit)
        .push(
          const PlayerReady(
            PlayerSession(sessionId: '42', streamUrl: 'http://127.0.0.1/2'),
            startPosition: Duration(minutes: 12, seconds: 34),
            showResumeNotice: true,
          ),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Said in the future while the file starts; the snackbar waits for it.
    expect(find.text('Picking up at 12:34'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Picking up at 12:34'), findsOneWidget);

    // The choice can be taken back before the file plays.
    await tester.tap(find.widgetWithText(TextButton, 'Start over'));
    await tester.pump();
    expect(find.text('Starting from the beginning'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'From 12:34'));
    await tester.pump();
    expect(find.text('Picking up at 12:34'), findsOneWidget);

    (tester.element(find.byType(PlayerPage)).read<PlayerCubit>()
            as FakePlayerCubit)
        .push(
          const PlayerReady(
            PlayerSession(sessionId: '42', streamUrl: 'http://127.0.0.1/2'),
            startPosition: Duration(minutes: 12, seconds: 34),
            showResumeNotice: true,
            started: true,
          ),
        );
    await tester.pump();
    expect(find.text('Resumed from 12:34'), findsOneWidget);

    // Its action belongs to that file: switching files closes it.
    (tester.element(find.byType(PlayerPage)).read<PlayerCubit>()
            as FakePlayerCubit)
        .push(const PlayerPreparing());
    // The loading spinner never settles; let the snackbar animate out.
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Resumed from 12:34'), findsNothing);
  });

  testWidgets('a torrent episode watched to its ending is offered for the '
      'list', (tester) async {
    setTestWindowSize(tester, const Size(400, 800));
    final rates = MockUserRateRepository();
    await tester.pumpWidget(_wrap(rates: rates));
    final cubit =
        tester.element(find.byType(PlayerPage)).read<PlayerCubit>()
            as FakePlayerCubit;

    cubit.push((cubit.state as PlayerReady).copyWith(watched: true));
    await tester.pumpAndSettle();

    expect(find.text('Mark episode 2 on Shikimori?'), findsOneWidget);
    await tester.tap(find.text('Mark'));
    await tester.pumpAndSettle();

    expect(rates.rates['5114']?.episodes, 2);
    expect(rates.rates['5114']?.status, UserRateStatus.watching);
    expect(find.text('Episode 2 marked on Shikimori'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(rates.rates['5114'], isNull);
  });

  group('on desktop', () {
    final desktop = TargetPlatformVariant.only(TargetPlatform.windows);

    testWidgets('an online episode is marked at once, inside the player', (
      tester,
    ) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      final rates = MockUserRateRepository();
      await tester.pumpWidget(_wrap(source: _onlineSource, rates: rates));
      final cubit =
          tester.element(find.byType(PlayerPage)).read<PlayerCubit>()
              as FakePlayerCubit;

      cubit.push((cubit.state as PlayerReady).copyWith(watched: true));
      await tester.pump();
      await tester.pump();

      expect(rates.rates['5114']?.episodes, 3);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.text('notice: Episode 3 marked on Shikimori / Undo'),
        findsOneWidget,
      );

      await tester.pump();
      await tester.pump(markNoticeDuration);
      await tester.pump();
      expect(find.textContaining('notice:'), findsNothing);
    }, variant: desktop);

    testWidgets('fills the window with the immersive player', (tester) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);

      await tester.pumpWidget(_wrap(source: _seriesSource));

      expect(find.byType(AppBar), findsNothing);
      expect(
        find.text('overline: Fullmetal Alchemist: Brotherhood'),
        findsOneWidget,
      );
      expect(find.text('title: Episode 2'), findsOneWidget);
      expect(
        find.text('titleDetail: of 3'),
        findsOneWidget,
        reason: 'the file is the second of three, as its number says',
      );
      expect(find.text('details: null'), findsOneWidget);
      expect(
        find.text(
          'episodes: [Mock] Fullmetal Alchemist: Brotherhood Batch · 3 episodes',
        ),
        findsOneWidget,
        reason: 'the full release name heads the drawer',
      );
      final theme = Theme.of(tester.element(find.text('title: Episode 2')));
      expect(theme.brightness, Brightness.dark);
      expect(tester.takeException(), isNull);
    }, variant: desktop);

    testWidgets('keeps the place apart when it differs from the number', (
      tester,
    ) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);

      await tester.pumpWidget(
        _wrap(
          source: const AnimePlayerSource(
            animeId: '5114',
            animeTitle: 'Season two',
            sourceTitle: 'Season two batch',
            sessionId: '42',
            fileIndex: 2,
            fileName: 'episode-14.mkv',
            files: [
              PlayerVideoFile(
                index: 1,
                name: 'episode-13.mkv',
                size: 1,
                extension: 'mkv',
              ),
              PlayerVideoFile(
                index: 2,
                name: 'episode-14.mkv',
                size: 1,
                extension: 'mkv',
              ),
            ],
          ),
        ),
      );

      expect(find.text('title: Episode 14'), findsOneWidget);
      expect(find.text('titleDetail: null'), findsOneWidget);
      expect(find.text('details: 2 of 2'), findsOneWidget);
    }, variant: desktop);

    testWidgets('names a torrent without an anime by its release', (
      tester,
    ) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);

      await tester.pumpWidget(
        _wrap(
          source: const AnimePlayerSource(
            animeId: '',
            animeTitle: '',
            sourceTitle: 'Some release',
            sessionId: '42',
            fileIndex: 0,
            fileName: 'Movie.mkv',
          ),
        ),
      );

      expect(find.text('overline: Some release'), findsOneWidget);
      expect(find.text('title: Movie'), findsOneWidget);
      expect(find.text('details: null'), findsOneWidget);

      // A new provider, so the page gets the new source.
      await tester.pumpWidget(
        KeyedSubtree(
          key: UniqueKey(),
          child: _wrap(
            source: const AnimePlayerSource(
              animeId: '',
              animeTitle: '[Group] Saved release (2006) [1080p]',
              sourceTitle: '[Group] Saved release (2006) [1080p]',
              sessionId: '42',
              fileIndex: 0,
              fileName: 'Movie.mkv',
            ),
          ),
        ),
      );
      expect(
        find.text('overline: Saved release'),
        findsOneWidget,
        reason: 'a saved torrent is named by its release, without tags',
      );
      expect(find.text('details: null'), findsOneWidget);
    }, variant: desktop);

    testWidgets('plays an episode picked in the drawer', (tester) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);

      await tester.pumpWidget(_wrap(source: _seriesSource));

      expect(find.text('NOW PLAYING'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('player_episode_card_3')));
      await tester.pump();
      final cubit =
          tester.element(find.byType(PlayerPage)).read<PlayerCubit>()
              as FakePlayerCubit;
      expect(cubit.playedFiles, [3]);

      await tester.tap(find.byKey(const ValueKey('player_episode_card_2')));
      expect(cubit.playedFiles, [3], reason: 'the current file plays');
    }, variant: desktop);

    testWidgets('announces the resume inside the player instead of a '
        'snackbar', (tester) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);
      await tester.pumpWidget(_wrap());
      final cubit =
          tester.element(find.byType(PlayerPage)).read<PlayerCubit>()
              as FakePlayerCubit;

      cubit.push(
        const PlayerReady(
          PlayerSession(sessionId: '42', streamUrl: 'http://127.0.0.1/2'),
          startPosition: Duration(minutes: 2, seconds: 22),
          showResumeNotice: true,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.text('notice: Picking up at 2:22 / Start over'),
        findsOneWidget,
      );

      // Pinned while the file starts, with a choice that can be undone.
      await tester.pump(const Duration(seconds: 20));
      cubit.restartFromBeginning();
      await tester.pump();
      await tester.pump();
      expect(
        find.text('notice: Starting from the beginning / From 2:22'),
        findsOneWidget,
      );

      // Counted down from the first frame.
      cubit.push((cubit.state as PlayerReady).copyWith(started: true));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('notice: Playing from the beginning / From 2:22'),
        findsOneWidget,
      );
      // The count starts with the next frame.
      await tester.pump();
      await tester.pump(const Duration(seconds: 7));
      expect(find.textContaining('notice:'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      // The dismissal reaches the page after that frame.
      await tester.pump();
      expect(find.textContaining('notice:'), findsNothing);
    }, variant: desktop);

    testWidgets('goes back from the player', (tester) async {
      setTestWindowSize(tester, TestWindowSizes.landscape);

      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => _page(fmaPlayerSource)),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerPage), findsOneWidget);

      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerPage), findsNothing);
    }, variant: desktop);
  });
}

Widget _wrap({
  AnimePlayerSource source = fmaPlayerSource,
  PlayerState state = const PlayerReady(
    PlayerSession(sessionId: '42', streamUrl: 'http://127.0.0.1:8080/stream/2'),
  ),
  MockUserRateRepository? rates,
}) {
  final page = _page(source, state);
  return testApp(
    rates == null
        ? page
        : BlocProvider(
            create: (_) => EpisodeMarkCubit(
              markEpisode: MarkEpisodeWatched(rates),
              userId: '42',
            ),
            child: page,
          ),
  );
}

Widget _page(
  AnimePlayerSource source, [
  PlayerState state = const PlayerReady(
    PlayerSession(sessionId: '42', streamUrl: 'http://127.0.0.1:8080/stream/2'),
  ),
]) {
  return BlocProvider<PlayerCubit>(
    create: (_) => FakePlayerCubit(state, source: source),
    child: const PlayerPage(viewportFactory: FakePlayerViewportFactory()),
  );
}

/// An online release: its episodes come numbered.
const _onlineSource = AnimePlayerSource(
  animeId: '5114',
  animeTitle: 'Fullmetal Alchemist: Brotherhood',
  sourceTitle: 'AniLibria',
  sessionId: '42',
  fileIndex: 3,
  fileName: 'Episode 3',
  files: [
    PlayerVideoFile(
      index: 3,
      name: 'Episode 3',
      size: 0,
      extension: '',
      episodeNumber: 3,
    ),
  ],
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
