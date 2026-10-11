import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_tab_cubit.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/online_sources/data/repositories/mock_online_sources_repository.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_cubit.dart';
import 'package:iris/shared/torrent/torrent_key.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_repository.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/features/watch_sources/presentation/pages/watch_sources_page.dart';
import 'package:iris/features/watch_sources/presentation/widgets/watch_sources_view.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/dither_transition.dart';
import 'package:iris/shared/widgets/search_field.dart';

import '../../../../helpers/fake_watch_progress_repository.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';
import '../../watch_sources_test_doubles.dart';

void main() {
  testWidgets('shows table-shaped noise while sources are loading', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final cubit = frierenSourcesCubit(PendingWatchSourcesRepository());

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pump();

    expect(tester.widget<AppSkeleton>(find.byType(AppSkeleton)).enabled, true);
    expect(find.bySemanticsLabel('Loading sources...'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Anime Title')), findsNothing);
    semantics.dispose();
  });

  testWidgets('the releases develop out of the noise', (tester) async {
    final sources = Completer<List<WatchSourceItem>>();
    final cubit = frierenSourcesCubit(
      PendingWatchSourcesRepository(sources.future),
    );

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pump();

    sources.complete(frierenSources);
    await tester.pump();
    await tester.pump(DitherTransition.duration ~/ 2);
    expect(find.text('[SubsPlease] Frieren - 28 (1080p)'), findsOneWidget);
    expect(find.textContaining('Anime Title'), findsWidgets);

    await tester.pump(DitherTransition.duration);
    expect(find.textContaining('Anime Title'), findsNothing);
  });

  testWidgets('shows search, sorting and source cards when loading succeeds', (
    tester,
  ) async {
    final cubit = frierenSourcesCubit(FixedWatchSourcesRepository());

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Search sources'), findsOneWidget);
    expect(find.text('Sort'), findsOneWidget);
    expect(find.text('[SubsPlease] Frieren - 28 (1080p)'), findsOneWidget);
    expect(find.text('[Judas] Frieren Season Pack Dual-Audio'), findsOneWidget);
    // Below the table breakpoint the numbers follow the name in one line.
    expect(
      find.text(
        '1.4 GiB · 33 seeders · 269 downloads · Apr 14, 2026',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('watch_source_watch_button')),
      findsNWidgets(3),
    );
    expect(find.byTooltip('Download'), findsNWidgets(3));
  });

  testWidgets('each source row streams on tap and downloads from its '
      'trailing button', (tester) async {
    final cubit = frierenSourcesCubit(FixedWatchSourcesRepository());

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('watch_source_watch_button'));
    final downloadButton = find.byKey(
      const Key('watch_source_download_button'),
    );
    expect(row, findsNWidgets(3));
    expect(downloadButton, findsNWidgets(3));
    expect(tester.widget<InkWell>(row.first).onTap, isNotNull);
    expect(
      find.descendant(of: row.first, matching: downloadButton),
      findsOneWidget,
    );
    expect(
      tester.getCenter(downloadButton.first).dx,
      greaterThan(tester.getCenter(find.text(frierenSources[1].title)).dx),
      reason: 'download is the trailing action',
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('Watch opens the streaming file picker for the source', (
    tester,
  ) async {
    final navigation = await _pumpRoutedView(tester);

    await tester.tap(find.byKey(const Key('watch_source_watch_button')).first);
    await tester.pumpAndSettle();

    expect(find.text('Streaming Files Route'), findsOneWidget);
    final args = navigation.extra as AnimePlayerSourceArgs;
    expect(args.animeId, '52991');
    expect(args.animeTitle, "Frieren: Beyond Journey's End");
    expect(args.sourceTitle, '[SubsPlease] Frieren - 28 (1080p)');
    expect(args.magnet, 'magnet:?xt=urn:btih:test-1');
  });

  testWidgets('Download opens the download file selection for the source', (
    tester,
  ) async {
    final navigation = await _pumpRoutedView(tester);

    await tester.tap(
      find.byKey(const Key('watch_source_download_button')).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Download Files Route'), findsOneWidget);
    final args = navigation.extra as DownloadSelectionArgs;
    expect(args.animeId, '52991');
    expect(args.animeTitle, "Frieren: Beyond Journey's End");
    expect(args.sourceTitle, '[SubsPlease] Frieren - 28 (1080p)');
    expect(args.magnet, 'magnet:?xt=urn:btih:test-1');
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
          ],
          child: const WatchSourcesPage(
            args: AnimeWatchSourcesArgs(
              animeId: '52991',
              animeTitle: "Frieren: Beyond Journey's End",
              searchTitles: ["Frieren: Beyond Journey's End"],
            ),
          ),
        ),
        locale: const Locale('ru'),
      ),
    );
    await tester.pumpAndSettle();

    final watchButton = find.byKey(const Key('watch_source_watch_button'));
    final downloadButton = find.byKey(
      const Key('watch_source_download_button'),
    );
    expect(find.byTooltip('Скачать'), findsWidgets);
    expect(
      tester
          .getRect(watchButton.first)
          .contains(tester.getCenter(downloadButton.first)),
      isTrue,
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
    // Filtering while typing updates the list without a transition.
    await tester.pump();
    expect(find.byType(ListView), findsOneWidget);

    expect(find.text('[Judas] Frieren Season Pack Dual-Audio'), findsOneWidget);
    expect(find.text('[SubsPlease] Frieren - 28 (1080p)'), findsNothing);
    expect(find.text('[ASW] Frieren - 27'), findsNothing);
  });

  testWidgets('keeps the typed query and caret while results filter', (
    tester,
  ) async {
    final cubit = frierenSourcesCubit(FixedWatchSourcesRepository());

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pumpAndSettle();

    final field = find.widgetWithText(TextField, 'Search sources');
    await tester.enterText(field, 'frien');
    await tester.pumpAndSettle();
    final controller = tester.widget<TextField>(field).controller!;
    controller.selection = const TextSelection.collapsed(offset: 2);
    await tester.enterText(field, 'frieren');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(field).controller, same(controller));
    expect(controller.text, 'frieren');
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

    expect(find.text('No sources match your search.'), findsOneWidget);
    expect(find.text('No sources found.'), findsNothing);
  });

  testWidgets('changes card order after selecting another sort option', (
    tester,
  ) async {
    final cubit = frierenSourcesCubit(FixedWatchSourcesRepository());

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pumpAndSettle();

    expect(_topTitle(tester), '[SubsPlease] Frieren - 28 (1080p)');

    await tester.tap(find.text('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Apply'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pump();
    await tester.pump(DitherTransition.duration ~/ 2);
    // The new order dissolves in over the old one.
    expect(find.byType(ListView), findsNWidgets(2));
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    expect(_topTitle(tester), '[ASW] Frieren - 27');
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
          child: const Scaffold(body: WatchSourcesView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_topTitle(tester), '[ASW] Frieren - 27');
    expect(find.byKey(const Key('watch_source_used_badge')), findsOneWidget);
    expect(find.textContaining('You watched this · '), findsOneWidget);
  });

  testWidgets('shows empty state when there are no results from repository', (
    tester,
  ) async {
    final cubit = WatchSourcesCubit(
      animeId: '52991',
      animeTitle: 'Unknown Title',
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
    expect(find.text('Try Again'), findsOneWidget);

    repository.shouldFail = false;
    await tester.tap(find.text('Try Again'));
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
            ],
            child: const WatchSourcesPage(
              args: AnimeWatchSourcesArgs(
                animeId: '52991',
                animeTitle: "Frieren: Beyond Journey's End",
                searchTitles: ["Frieren: Beyond Journey's End"],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final first = tester.getTopLeft(
        find.text('[SubsPlease] Frieren - 28 (1080p)'),
      );
      final second = tester.getTopLeft(
        find.text('[Judas] Frieren Season Pack Dual-Audio'),
      );
      expect(second.dy, greaterThan(first.dy), reason: 'one list column');
      final watchButton = find.byKey(const Key('watch_source_watch_button'));
      final downloadButton = find.byKey(
        const Key('watch_source_download_button'),
      );
      expect(
        tester
            .getRect(watchButton.first)
            .contains(tester.getCenter(downloadButton.first)),
        isTrue,
        reason: 'download is the row trailing action',
      );
      expect(tester.takeException(), isNull);

      // Narrow windows show the action as an icon, named by its tooltip.
      await tester.tap(
        entry.value.width < 600 ? find.byTooltip('Sort') : find.text('Sort'),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(Dialog),
        entry.value.width < 600 ? findsNothing : findsOneWidget,
      );
      expect(find.text('Apply'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpView(
  WidgetTester tester, {
  required WatchSourcesCubit cubit,
}) async {
  await tester.pumpWidget(
    testApp(
      BlocProvider.value(
        value: cubit,
        child: const Scaffold(body: WatchSourcesView()),
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
          child: const Scaffold(body: WatchSourcesView()),
        ),
      ),
      GoRoute(
        path: '/torrent/watch',
        name: 'torrent-stream-files',
        builder: (context, state) =>
            recordRoute(state, 'Streaming Files Route'),
      ),
      GoRoute(
        path: '/torrent/download',
        name: 'torrent-download-files',
        builder: (context, state) => recordRoute(state, 'Download Files Route'),
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
