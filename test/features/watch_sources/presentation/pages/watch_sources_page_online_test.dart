import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress_repository.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/online_sources/domain/entities/online_episode.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_cubit.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_repository.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/features/watch_sources/presentation/pages/watch_sources_page.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/online/online_source_link.dart';

import '../../../../helpers/test_window.dart';

const _link = 'online:anilibria/9542?anime=52991';

final _release = OnlineRelease(
  provider: OnlineProvider.anilibria,
  id: '9542',
  title: 'Провожающая в последний путь Фрирен',
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
      title: '',
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
  testWidgets('puts the online release over the torrents, each labelled', (
    tester,
  ) async {
    await _pumpPage(tester, online: _FakeOnlineSources.found());

    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.text('TORRENTS'), findsOneWidget);
    expect(find.text('AniLibria'), findsOneWidget);
    expect(
      find.text('28 episodes · up to 1080p', findRichText: true),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('AniLibria')).dy,
      lessThan(tester.getTopLeft(find.text('[SubsPlease] Frieren')).dy),
    );
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

  testWidgets('without an online release the torrents need no label', (
    tester,
  ) async {
    await _pumpPage(tester, online: _FakeOnlineSources(const []));

    expect(find.text('ONLINE'), findsNothing);
    expect(find.text('TORRENTS'), findsNothing);
    expect(find.text('[SubsPlease] Frieren'), findsOneWidget);
  });

  testWidgets('keeps the torrent search when the online labels go', (
    tester,
  ) async {
    final online = _FakeOnlineSources.pending();
    await _pumpPage(tester, online: online);

    await tester.enterText(find.byType(TextField), 'subs');
    await tester.pump();
    online.answer.complete(const []);
    await tester.pumpAndSettle();

    expect(find.text('ONLINE'), findsNothing);
    expect(find.text('subs'), findsOneWidget);
  });

  testWidgets('shows a loading row while servers are searched', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpPage(tester, online: _FakeOnlineSources.pending());

    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.bySemanticsLabel('Looking for online sources'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a failed search offers to retry and keeps the torrents', (
    tester,
  ) async {
    final online = _FakeOnlineSources.failing();
    await _pumpPage(tester, online: online);

    expect(find.text('Online sources did not respond.'), findsOneWidget);
    expect(find.text('[SubsPlease] Frieren'), findsOneWidget);

    online.fail = false;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(online.searches, 2);
    expect(find.text('AniLibria'), findsOneWidget);
  });

  testWidgets('keeps three dubs on the page and lists all in a sheet', (
    tester,
  ) async {
    final navigation = await _pumpPage(
      tester,
      online: _FakeOnlineSources(_dubs),
    );

    expect(find.text('AniLibria'), findsOneWidget);
    expect(find.text('AniDUB'), findsOneWidget);
    expect(find.text('Dream Cast'), findsOneWidget);
    expect(find.text('SHIZA Project'), findsNothing);
    expect(find.text('All dubs · 5'), findsOneWidget);

    await tester.tap(find.text('All dubs · 5'));
    await tester.pumpAndSettle();
    expect(find.text('Dubs'), findsOneWidget);
    await tester.tap(find.text('SHIZA Project'));
    await tester.pumpAndSettle();

    expect(find.text('File picker'), findsOneWidget);
    final args = navigation.extra! as AnimePlayerSourceArgs;
    expect(args.sourceTitle, 'SHIZA Project');
    expect(args.magnet, 'online:yummyAnime/10661:shiza?anime=52991');
  });

  testWidgets('puts the dubs the user watched from first', (tester) async {
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

    expect(find.text('AniStar'), findsOneWidget);
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

  for (final entry in TestWindowSizes.all.entries) {
    testWidgets('lays out the online row without overflow on ${entry.key}', (
      tester,
    ) async {
      setTestWindowSize(tester, entry.value);
      await _pumpPage(tester, online: _FakeOnlineSources.found());

      expect(find.text('AniLibria'), findsOneWidget);
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
                repository: const _Torrents(),
              )..loadSources(),
            ),
            BlocProvider(
              create: (_) => OnlineReleasesCubit(
                shikimoriId: args.animeId,
                titles: args.searchTitles,
                repository: online,
              )..load(),
            ),
            BlocProvider(
              create: (_) =>
                  WatchProgressCubit(repository: _History(history))..load(),
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

  await tester.pumpWidget(
    MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return navigation;
}

class _FakeOnlineSources implements OnlineSourcesRepository {
  _FakeOnlineSources(this.releases);

  _FakeOnlineSources.found() : releases = [_release];

  _FakeOnlineSources.pending() : releases = const [], pendingAnswer = true;

  _FakeOnlineSources.failing() : releases = [_release], fail = true;

  final List<OnlineRelease> releases;
  bool pendingAnswer = false;
  bool fail = false;
  int searches = 0;
  final answer = Completer<List<OnlineRelease>>();

  @override
  Future<List<OnlineRelease>> findReleases({
    required String shikimoriId,
    required List<String> titles,
  }) async {
    searches++;
    if (pendingAnswer) return answer.future;
    if (fail) throw StateError('offline');
    return releases;
  }

  @override
  Future<OnlineRelease> fetchRelease({
    required OnlineProvider provider,
    required String id,
  }) => throw UnimplementedError();

  @override
  Future<List<OnlineStream>> resolveStreams({
    required OnlineProvider provider,
    required String episodeId,
  }) => throw UnimplementedError();
}

class _Torrents implements WatchSourcesRepository {
  const _Torrents();

  @override
  Future<List<WatchSourceItem>> fetchSources(List<String> titles) async => [
    const WatchSourceItem(
      title: '[SubsPlease] Frieren',
      category: 'Anime - English-translated',
      link: 'https://nyaa.example/1',
      torrent: '',
      magnet: 'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
      size: '1.4 GiB',
      time: '2026-04-14',
      seeders: 33,
      leechers: 1,
      downloads: 269,
    ),
  ];
}

class _History implements WatchProgressRepository {
  _History(this.items);

  final List<WatchProgress> items;

  @override
  Stream<List<WatchProgress>> watchAll() => Stream.value(items);

  @override
  Future<WatchProgress?> find({
    required String torrentKey,
    required int fileIndex,
  }) async => null;

  @override
  Future<void> save(WatchProgress progress) async {}

  @override
  Future<void> removeTorrent({required String torrentKey}) async {}
}
