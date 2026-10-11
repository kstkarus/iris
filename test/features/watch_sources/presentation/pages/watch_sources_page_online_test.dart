import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/online_sources/domain/entities/online_episode.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/repositories/online_releases_search.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_cubit.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_sources_tab.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_repository.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_tab_cubit.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/features/watch_sources/presentation/pages/watch_sources_page.dart';
import 'package:iris/shared/online/online_source_link.dart';

import '../../../../helpers/fake_watch_progress_repository.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';
import '../../watch_sources_test_doubles.dart';

const _link = 'online:anilibria/9542?anime=52991';

final _release = OnlineRelease(
  provider: OnlineProvider.anilibria,
  id: '9542',
  dub: 'AniLibria',
  episodes: [
    for (var number = 1; number <= 28; number++)
      OnlineEpisode(id: 'e$number', number: number),
  ],
  bestQuality: 1080,
);

OnlineRelease _dub(OnlineProvider provider, String id, String dub) =>
    OnlineRelease(
      provider: provider,
      id: id,
      dub: dub,
      episodes: const [OnlineEpisode(id: 'e1', number: 1)],
      bestQuality: 720,
    );

final _dubs = [
  _release,
  _dub(OnlineProvider.yummyAnime, '10661:anidub', 'AniDUB'),
  _dub(OnlineProvider.yummyAnime, '10661:dreamcast', 'Dream Cast'),
  _dub(OnlineProvider.yummyAnime, '10661:shiza', 'SHIZA Project'),
  _dub(OnlineProvider.yummyAnime, '10661:anistar', 'AniStar'),
];

void main() {
  testWidgets('opens on the online tab the first time', (tester) async {
    await _pumpPage(tester, online: _FakeOnlineSources.found());

    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Torrents'), findsOneWidget);
    expect(find.text('AniLibria'), findsOneWidget);
    expect(
      find.text('28 episodes · up to 1080p', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('[SubsPlease] Frieren'), findsNothing);
  });

  testWidgets('a tap shows the torrents and is remembered', (tester) async {
    final tabs = MemoryWatchSourcesTabRepository();
    await _pumpPage(tester, online: _FakeOnlineSources.found(), tabs: tabs);

    await tester.tap(find.text('Torrents'));
    await tester.pumpAndSettle();

    expect(find.text('[SubsPlease] Frieren'), findsOneWidget);
    expect(find.text('AniLibria'), findsNothing);
    expect(tabs.tab, WatchSourcesTab.torrents);
  });

  testWidgets('opens on the tab chosen last', (tester) async {
    await _pumpPage(
      tester,
      online: _FakeOnlineSources.found(),
      tabs: MemoryWatchSourcesTabRepository(WatchSourcesTab.torrents),
    );

    expect(find.text('[SubsPlease] Frieren'), findsOneWidget);
    expect(find.text('AniLibria'), findsNothing);
  });

  testWidgets('keeps the torrent search while the other tab shows', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      online: _FakeOnlineSources.found(),
      tabs: MemoryWatchSourcesTabRepository(WatchSourcesTab.torrents),
    );

    await tester.enterText(find.byType(TextField), 'subs');
    await tester.pump();
    await tester.tap(find.text('Online'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Torrents'));
    await tester.pumpAndSettle();

    expect(find.text('subs'), findsOneWidget);
  });

  testWidgets('lists every dub on the online tab', (tester) async {
    await _pumpPage(tester, online: _FakeOnlineSources(_dubs));

    for (final release in _dubs) {
      expect(find.text(release.dub), findsOneWidget);
    }
  });

  testWidgets('sets the dubs in columns on a wide window', (tester) async {
    setTestWindowSize(tester, TestWindowSizes.desktop);
    await _pumpPage(tester, online: _FakeOnlineSources(_dubs));

    final first = tester.getTopLeft(find.text('AniLibria'));
    final second = tester.getTopLeft(find.text('AniDUB'));
    expect(second.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
  });

  testWidgets('keeps the dubs in one column on a phone', (tester) async {
    setTestWindowSize(tester, TestWindowSizes.phone);
    await _pumpPage(tester, online: _FakeOnlineSources(_dubs));

    final first = tester.getTopLeft(find.text('AniLibria'));
    final second = tester.getTopLeft(find.text('AniDUB'));
    expect(second.dx, first.dx);
    expect(second.dy, greaterThan(first.dy));
  });

  testWidgets('opens the release episodes in the file picker', (tester) async {
    final navigation = await _pumpPage(
      tester,
      online: _FakeOnlineSources.found(),
    );

    await tester.tap(
      find.byKey(const ValueKey('online_release_anilibria_9542')),
    );
    await tester.pumpAndSettle();

    expect(find.text('File picker'), findsOneWidget);
    final args = navigation.extra! as AnimePlayerSourceArgs;
    expect(args.magnet, _link);
    expect(args.sourceTitle, 'AniLibria');
    expect(args.animeId, '52991');
    expect(args.animeTitle, 'Frieren');
  });

  testWidgets('marks a release the user has watched from', (tester) async {
    await _pumpPage(
      tester,
      online: _FakeOnlineSources.found(),
      history: [
        WatchProgress(
          torrentKey: sourceProgressKey(_link),
          fileIndex: 3,
          fileName: '04 «Пристанище душ»',
          magnet: _link,
          sourceTitle: 'AniLibria',
          position: const Duration(minutes: 12),
          duration: const Duration(minutes: 26),
          updatedAt: DateTime(2026, 10, 9),
        ),
      ],
    );

    expect(
      find.textContaining('· 28 episodes · up to 1080p', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('puts the dubs the user watched from first', (tester) async {
    setTestWindowSize(tester, TestWindowSizes.phone);
    const link = 'online:yummyAnime/10661:anistar?anime=52991';
    await _pumpPage(
      tester,
      online: _FakeOnlineSources(_dubs),
      history: [
        WatchProgress(
          torrentKey: sourceProgressKey(link),
          fileIndex: 2,
          fileName: '02',
          magnet: link,
          sourceTitle: 'AniStar',
          position: const Duration(minutes: 3),
          duration: const Duration(minutes: 24),
          updatedAt: DateTime(2026, 10, 9),
        ),
      ],
    );

    expect(
      tester.getTopLeft(find.text('AniStar')).dy,
      lessThan(tester.getTopLeft(find.text('AniLibria')).dy),
    );
    // Only the dub watched from is marked, though all share the progress.
    expect(
      find.textContaining('You watched this', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('without an online release the torrents are the page', (
    tester,
  ) async {
    await _pumpPage(tester, online: _FakeOnlineSources(const []));
    await tester.pumpAndSettle();

    expect(find.text('Online'), findsNothing);
    expect(find.text('Torrents'), findsNothing);
    expect(find.text('[SubsPlease] Frieren'), findsOneWidget);
  });

  testWidgets('without torrents the online releases are the page', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      online: _FakeOnlineSources.found(),
      torrents: const _Torrents.none(),
      // The chosen tab has nothing: the page shows what there is.
      tabs: MemoryWatchSourcesTabRepository(WatchSourcesTab.torrents),
    );
    await tester.pumpAndSettle();

    expect(find.text('Online'), findsNothing);
    expect(find.text('AniLibria'), findsOneWidget);
  });

  testWidgets('dissolves the tabs when nothing is found online', (
    tester,
  ) async {
    final tabs = MemoryWatchSourcesTabRepository();
    final online = _FakeOnlineSources.pending();
    await _pumpPage(tester, online: online, tabs: tabs);

    await online.answers.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Still there, going cell by cell.
    expect(find.text('Online'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Online'), findsNothing);
    expect(find.text('[SubsPlease] Frieren'), findsOneWidget);
    // Shown for want of online releases, not chosen.
    expect(tabs.tab, isNull);
  });

  testWidgets('keeps the torrent search when the tabs go', (tester) async {
    final online = _FakeOnlineSources.pending();
    await _pumpPage(
      tester,
      online: online,
      tabs: MemoryWatchSourcesTabRepository(WatchSourcesTab.torrents),
    );

    await tester.enterText(find.byType(TextField), 'subs');
    await tester.pump();
    await online.answers.close();
    await tester.pumpAndSettle();

    expect(find.text('Online'), findsNothing);
    expect(find.text('subs'), findsOneWidget);
  });

  testWidgets('shows noise rows while servers are searched', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpPage(tester, online: _FakeOnlineSources.pending());

    expect(find.text('Online'), findsOneWidget);
    expect(find.bySemanticsLabel('Looking for online sources'), findsWidgets);
    semantics.dispose();
  });

  testWidgets('shows a fast server\'s dubs while a slow one searches', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final online = _FakeOnlineSources.pending();
    await _pumpPage(tester, online: online);

    online.answers.add([_release]);
    // The noise never settles.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.byKey(const ValueKey('online_release_anilibria_9542')),
      findsOneWidget,
    );
    // A noise row waits for the slow server, heard apart from the dub
    // beside it.
    expect(find.bySemanticsLabel('Looking for online sources'), findsOneWidget);

    online.answers.add(_dubs);
    await online.answers.close();
    await tester.pumpAndSettle();
    expect(find.text('AniDUB'), findsOneWidget);
    expect(find.bySemanticsLabel('Looking for online sources'), findsNothing);
    semantics.dispose();
  });

  testWidgets('a failed search offers to retry on its tab', (tester) async {
    final online = _FakeOnlineSources.failing();
    await _pumpPage(tester, online: online);

    expect(find.text('Online sources did not respond.'), findsOneWidget);
    expect(find.text('Torrents'), findsOneWidget);

    online.fail = false;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(online.searches, 2);
    expect(find.text('AniLibria'), findsOneWidget);
  });

  for (final entry in TestWindowSizes.all.entries) {
    testWidgets('lays out both tabs without overflow on ${entry.key}', (
      tester,
    ) async {
      setTestWindowSize(tester, entry.value);
      await _pumpPage(tester, online: _FakeOnlineSources(_dubs));
      await tester.tap(find.text('Torrents'));
      await tester.pumpAndSettle();

      expect(find.text('[SubsPlease] Frieren'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _RecordedNavigation {
  Object? extra;
}

Future<_RecordedNavigation> _pumpPage(
  WidgetTester tester, {
  required _FakeOnlineSources online,
  _Torrents torrents = const _Torrents(),
  MemoryWatchSourcesTabRepository? tabs,
  List<WatchProgress> history = const [],
}) async {
  final navigation = _RecordedNavigation();
  const args = AnimeWatchSourcesArgs(
    animeId: '52991',
    animeTitle: 'Frieren',
    searchTitles: ['Frieren'],
  );
  final router = GoRouter(
    initialLocation: '/sources',
    routes: [
      GoRoute(
        path: '/sources',
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => WatchSourcesCubit(
                animeId: args.animeId,
                animeTitle: args.animeTitle,
                searchTitles: args.searchTitles,
                repository: torrents,
              )..loadSources(),
            ),
            BlocProvider(
              create: (_) => OnlineReleasesCubit(
                shikimoriId: args.animeId,
                titles: args.searchTitles,
                search: online,
              )..load(),
            ),
            BlocProvider(
              create: (_) => WatchSourcesTabCubit(
                repository: tabs ?? MemoryWatchSourcesTabRepository(),
              ),
            ),
            BlocProvider(
              create: (_) => WatchProgressCubit(
                repository: FixedWatchProgressRepository(history),
              )..load(),
            ),
          ],
          child: const WatchSourcesPage(args: args),
        ),
      ),
      GoRoute(
        path: '/torrent/watch',
        name: 'torrent-stream-files',
        builder: (context, state) {
          navigation.extra = state.extra;
          return const Scaffold(body: Text('File picker'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(testRouterApp(router));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return navigation;
}

class _FakeOnlineSources implements OnlineReleasesSearch {
  _FakeOnlineSources(this.releases);

  _FakeOnlineSources.found() : releases = [_release];

  _FakeOnlineSources.pending() : releases = const [], pendingAnswer = true;

  _FakeOnlineSources.failing() : releases = [_release], fail = true;

  final List<OnlineRelease> releases;
  bool pendingAnswer = false;
  bool fail = false;
  int searches = 0;

  /// The servers' answers while [pendingAnswer]; closing it ends the
  /// search.
  final answers = StreamController<List<OnlineRelease>>();

  @override
  Stream<List<OnlineRelease>> watchReleases({
    required String shikimoriId,
    required List<String> titles,
  }) {
    searches++;
    if (pendingAnswer) return answers.stream;
    if (fail) return Stream.error(StateError('offline'));
    return releases.isEmpty ? const Stream.empty() : Stream.value(releases);
  }
}

class _Torrents implements WatchSourcesRepository {
  const _Torrents() : found = true;

  const _Torrents.none() : found = false;

  final bool found;

  @override
  Future<List<WatchSourceItem>> fetchSources(List<String> titles) async => [
    if (found)
      const WatchSourceItem(
        title: '[SubsPlease] Frieren',
        magnet: 'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
        size: '1.4 GiB',
        time: '2026-04-14',
        seeders: 33,
        downloads: 269,
      ),
  ];
}
