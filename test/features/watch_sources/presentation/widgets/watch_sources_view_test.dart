import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

import 'package:iris/entities/anime/domain/anime_titles.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_tab_cubit.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/online_sources/data/repositories/mock_online_sources_repository.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_cubit.dart';
import 'package:iris/shared/torrent/torrent_key.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_repository.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_state.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/features/watch_sources/presentation/models/watch_sources_sort_option.dart';
import 'package:iris/features/watch_sources/presentation/pages/watch_sources_page.dart';
import 'package:iris/features/watch_sources/presentation/widgets/watch_sources_view.dart';
import 'package:iris/shared/widgets/search_field.dart';

import 'package:iris/features/saved_torrents/presentation/cubit/saved_torrents_cubit.dart';
import '../../../../helpers/memory_saved_torrents_repository.dart';
import '../../../../helpers/fake_watch_progress_repository.dart';
import '../../../../helpers/record_haptics.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';
import '../../watch_sources_test_doubles.dart';

void main() {
  testWidgets('announces while sources are loading', (tester) async {
    final semantics = tester.ensureSemantics();
    final cubit = frierenSourcesCubit(PendingWatchSourcesRepository());

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pump();

    expect(find.bySemanticsLabel('Loading sources'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a torrent row opens the release with its poster', (
    tester,
  ) async {
    final navigation = await _pumpRoutedView(tester);

    await tester.tap(find.byKey(const Key('watch_source_watch_button')).first);
    await tester.pumpAndSettle();

    expect(find.text('Release Route'), findsOneWidget);
    final args = navigation.extra as AnimePlayerSourceArgs;
    expect(args.animeId, '52991');
    expect(args.animeTitles.name, "Frieren: Beyond Journey's End");
    expect(args.sourceTitle, '[SubsPlease] Frieren - 28 (1080p)');
    expect(args.magnet, 'magnet:?xt=urn:btih:test-1');
    expect(args.posterUrl, 'https://example.test/poster.png');
  });

  testWidgets('fits source rows on very narrow phones without overflow', (
    tester,
  ) async {
    setTestWindowSize(tester, const Size(320, 640));
    final cubit = frierenSourcesCubit(FixedWatchSourcesRepository());

    await tester.pumpWidget(
      testApp(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit..loadSources()),
            BlocProvider(create: (_) => _noOnlineReleases()),
            BlocProvider(create: (_) => _tabs()),
            BlocProvider(create: (_) => _mine()),
          ],
          child: const WatchSourcesPage(
            args: AnimeWatchSourcesArgs(
              animeId: '52991',
              animeTitles: AnimeTitles(name: "Frieren: Beyond Journey's End"),
              searchTitles: ["Frieren: Beyond Journey's End"],
            ),
          ),
        ),
        locale: const Locale('ru'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('watch_source_watch_button')).hitTestable(),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters cards by local title search', (tester) async {
    final cubit = frierenSourcesCubit(FixedWatchSourcesRepository());

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Search sources'),
      'dual',
    );
    await tester.pump();

    expect(find.text('[Judas] Frieren Season Pack Dual-Audio'), findsOneWidget);
    expect(find.text('[SubsPlease] Frieren - 28 (1080p)'), findsNothing);
    expect(find.text('[ASW] Frieren - 27'), findsNothing);
  });

  testWidgets('clears the source search with the Clear button', (tester) async {
    final cubit = frierenSourcesCubit(FixedWatchSourcesRepository());

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pumpAndSettle();
    expect(find.byKey(SearchField.clearButtonKey), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search sources'),
      'dual',
    );
    await tester.pumpAndSettle();
    expect(find.text('[ASW] Frieren - 27'), findsNothing);

    await tester.tap(find.byKey(SearchField.clearButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('[ASW] Frieren - 27'), findsOneWidget);
    expect(find.byKey(SearchField.clearButtonKey), findsNothing);
  });

  testWidgets('shows dedicated empty state for local search results', (
    tester,
  ) async {
    final cubit = frierenSourcesCubit(FixedWatchSourcesRepository());

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Search sources'),
      'nothing',
    );
    await tester.pumpAndSettle();

    expect(find.text('No matching sources.'), findsOneWidget);
    expect(find.text('No sources found.'), findsNothing);

    // Clearing search returns to the results list cleanly.
    await tester.tap(find.byKey(SearchField.clearButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('[SubsPlease] Frieren - 28 (1080p)'), findsOneWidget);
  });

  testWidgets(
    'empty-search transition completes immediately with reduced motion',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final cubit = frierenSourcesCubit(FixedWatchSourcesRepository());
      await _pumpView(tester, cubit: cubit..loadSources());
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Search sources'),
        'nothing',
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('No matching sources.'), findsOneWidget);
    },
  );

  testWidgets('sorts compact cards by size from the sort sheet', (
    tester,
  ) async {
    final cubit = frierenSourcesCubit(FixedWatchSourcesRepository());

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pumpAndSettle();

    expect(_topTitle(tester), '[SubsPlease] Frieren - 28 (1080p)');

    await tester.tap(find.text('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Size'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Apply'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(_topTitle(tester), frierenMostDownloadedSource.title);
  });

  testWidgets('wide torrent headers sort the rows and announce the selection', (
    tester,
  ) async {
    setTestWindowSize(tester, TestWindowSizes.landscape);
    final cubit = frierenSourcesCubit(FixedWatchSourcesRepository());
    addTearDown(cubit.close);
    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pumpAndSettle();

    for (final (label, option, first) in const [
      ('Release', WatchSourcesSortOption.titleAsc, frierenOldSource),
      ('Size', WatchSourcesSortOption.sizeDesc, frierenMostDownloadedSource),
      ('Seeders', WatchSourcesSortOption.seedersDesc, frierenMostSeededSource),
      (
        'Downloads',
        WatchSourcesSortOption.downloadsDesc,
        frierenMostDownloadedSource,
      ),
      (
        'Date',
        WatchSourcesSortOption.publishedAtDesc,
        frierenMostDownloadedSource,
      ),
    ]) {
      final header = find.text(label);
      final bounds = tester.getRect(header);
      await tester.tap(header);
      await tester.pumpAndSettle();

      expect((cubit.state as WatchSourcesLoaded).sortOption, option);
      expect(_topTitle(tester), first.title);
      expect(tester.getRect(header), bounds);
      expect(
        find.semantics.byLabel(label).evaluate(),
        contains(
          isSemantics(isButton: true, isSelected: true, hasTapAction: true),
        ),
      );
    }
  });

  testWidgets('puts releases the user streamed first with a badge', (
    tester,
  ) async {
    final cubit = frierenSourcesCubit(FixedWatchSourcesRepository());
    final history = WatchProgressCubit(
      repository: FixedWatchProgressRepository([
        WatchProgress(
          torrentKey: torrentKeyFromMagnet('magnet:?xt=urn:btih:test-3'),
          fileIndex: 0,
          fileName: 'Frieren - 27.mkv',
          magnet: 'magnet:?xt=urn:btih:test-3',
          sourceTitle: '[ASW] Frieren - 27',
          position: const Duration(minutes: 3),
          duration: const Duration(minutes: 24),
          updatedAt: DateTime.utc(2026, 10, 4),
        ),
      ]),
    )..load();
    addTearDown(history.close);

    await tester.pumpWidget(
      testApp(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: history),
            BlocProvider.value(value: cubit..loadSources()),
          ],
          child: Scaffold(body: WatchSourcesView(onAddTorrent: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_topTitle(tester), '[ASW] Frieren - 27');
    expect(find.byKey(const Key('watch_source_used_badge')), findsOneWidget);
    expect(find.textContaining('Watched', findRichText: true), findsOneWidget);
  });

  testWidgets('shows empty state when there are no results from repository', (
    tester,
  ) async {
    final cubit = WatchSourcesCubit(
      animeId: '52991',
      animeTitles: const AnimeTitles(name: 'Unknown Title'),
      searchTitles: ['Unknown Title'],
      repository: FixedWatchSourcesRepository([]),
    );

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pumpAndSettle();

    expect(find.text('No sources found.'), findsOneWidget);
  });

  testWidgets('shows error state and retries loading', (tester) async {
    final repository = _ToggleWatchSourcesRepository();
    final cubit = frierenSourcesCubit(repository);

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pumpAndSettle();

    expect(find.text('Unable to load sources.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    repository.shouldFail = false;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('[SubsPlease] Frieren - 28 (1080p)'), findsOneWidget);
  });

  for (final entry in TestWindowSizes.all.entries) {
    testWidgets('lays out source rows without overflow on ${entry.key}', (
      tester,
    ) async {
      setTestWindowSize(tester, entry.value);
      final cubit = frierenSourcesCubit(FixedWatchSourcesRepository());

      await tester.pumpWidget(
        testApp(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit..loadSources()),
              BlocProvider(create: (_) => _noOnlineReleases()),
              BlocProvider(create: (_) => _tabs()),
              BlocProvider(create: (_) => _mine()),
            ],
            child: const WatchSourcesPage(
              args: AnimeWatchSourcesArgs(
                animeId: '52991',
                animeTitles: AnimeTitles(name: "Frieren: Beyond Journey's End"),
                searchTitles: ["Frieren: Beyond Journey's End"],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('[SubsPlease] Frieren - 28 (1080p)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      if (entry.value.width >= 1000) {
        // Tabular desktop layout sorts directly via column headers.
        expect(find.text('Sort'), findsNothing);
        await tester.tap(find.text('Size'));
        await tester.pumpAndSettle();
        expect(_topTitle(tester), frierenMostDownloadedSource.title);
      } else {
        // Narrow windows show the action as an icon, named by its tooltip.
        await tester.tap(
          entry.value.width < 600 ? find.byTooltip('Sort') : find.text('Sort'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Apply'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'sort changes vibrate selection on Android only when option changes',
    (tester) async {
      final effects = recordHaptics();
      setTestWindowSize(tester, TestWindowSizes.phone);
      final cubit = frierenSourcesCubit(FixedWatchSourcesRepository())
        ..loadSources();
      addTearDown(cubit.close);

      await _pumpView(tester, cubit: cubit);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Sort'));
      await tester.pumpAndSettle();

      // Re-tapping the already-selected default option stays silent.
      await tester.tap(find.text('Seeders'));
      await tester.pumpAndSettle();
      expect(effects, isEmpty);

      // Picking a different sort option vibrates selection on Android only.
      await tester.tap(find.text('Size'));
      await tester.pumpAndSettle();
      expect(effects, [
        if (defaultTargetPlatform == TargetPlatform.android)
          HapticsType.selection,
      ]);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );
}

Future<void> _pumpView(
  WidgetTester tester, {
  required WatchSourcesCubit cubit,
}) async {
  await tester.pumpWidget(
    testApp(
      BlocProvider.value(
        value: cubit,
        child: Scaffold(body: WatchSourcesView(onAddTorrent: () {})),
      ),
    ),
  );
}

class _RecordedNavigation {
  Object? extra;
}

Future<_RecordedNavigation> _pumpRoutedView(WidgetTester tester) async {
  final navigation = _RecordedNavigation();
  final cubit = frierenSourcesCubit(FixedWatchSourcesRepository())
    ..loadSources();
  addTearDown(cubit.close);

  Widget recordRoute(GoRouterState state, String label) {
    navigation.extra = state.extra;
    return Scaffold(body: Text(label));
  }

  final router = GoRouter(
    initialLocation: '/sources',
    routes: [
      GoRoute(
        path: '/sources',
        builder: (context, state) => BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: WatchSourcesView(
              onAddTorrent: () {},
              posterUrl: 'https://example.test/poster.png',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/torrent/watch',
        name: 'torrent-stream-files',
        builder: (context, state) => recordRoute(state, 'Release Route'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(testRouterApp(router));
  await tester.pumpAndSettle();

  return navigation;
}

String _topTitle(WidgetTester tester) {
  final titles = tester
      .widgetList<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.startsWith('['),
        ),
      )
      .map((widget) => widget.data!)
      .toList(growable: false);

  return titles.first;
}

SavedTorrentsCubit _mine() => SavedTorrentsCubit(
  animeId: '52991',
  repository: MemorySavedTorrentsRepository(),
)..load();

WatchSourcesTabCubit _tabs() =>
    WatchSourcesTabCubit(repository: MemoryWatchSourcesTabRepository());

OnlineReleasesCubit _noOnlineReleases() => OnlineReleasesCubit(
  shikimoriId: '52991',
  titles: const [],
  search: const MockOnlineSourcesRepository(),
)..load();

class _ToggleWatchSourcesRepository implements WatchSourcesRepository {
  bool shouldFail = true;

  @override
  Future<List<WatchSourceItem>> fetchSources(List<String> titles) async {
    if (shouldFail) {
      throw Exception('First call fails');
    }

    return frierenSources;
  }
}
