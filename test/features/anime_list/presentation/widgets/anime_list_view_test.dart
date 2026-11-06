import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/anime_list/domain/entities/anime_genre.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_page_result.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_list_repository.dart';
import 'package:iris/features/anime_list/domain/repositories/search_history_repository.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_search_bloc.dart';
import 'package:iris/features/anime_list/presentation/cubit/search_history_cubit.dart';
import 'package:iris/features/anime_list/presentation/pages/anime_list_page.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_card.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_list_view.dart';
import 'package:iris/features/anime_list/presentation/widgets/continue_watching_button.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/dither_transition.dart';
import 'package:iris/shared/widgets/search_field.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/features/anime_list/presentation/widgets/recent_searches.dart';
import 'package:iris/shared/widgets/search_toolbar.dart';

import '../../../../helpers/fake_watch_progress_repository.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';

void main() {
  testWidgets('shows rows of card-shaped noise while anime are loading', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final bloc = AnimeListBloc(repository: _PendingAnimeListRepository());

    await tester.pumpWidget(
      _wrapWithApp(
        BlocProvider.value(
          value: bloc..add(const AnimeListStarted()),
          child: const Scaffold(body: AnimeListView()),
        ),
      ),
    );

    await tester.pump();

    final rows = tester.widgetList<AppSkeleton>(find.byType(AppSkeleton));
    expect(rows, isNotEmpty);
    expect(rows.every((row) => row.enabled), isTrue);
    expect(find.bySemanticsLabel('Loading anime list...'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('anime title')), findsNothing);
    semantics.dispose();
  });

  testWidgets('cards develop out of the noise when the page arrives', (
    tester,
  ) async {
    final page = Completer<AnimeListPageResult>();
    final bloc = AnimeListBloc(
      repository: _PendingAnimeListRepository(page.future),
    );

    await tester.pumpWidget(
      _wrapWithApp(
        BlocProvider.value(
          value: bloc..add(const AnimeListStarted()),
          child: const Scaffold(body: AnimeListView()),
        ),
      ),
    );
    await tester.pump();

    page.complete(_withHasMore(_pageOneResult, false));
    await tester.pump();
    await tester.pump(DitherTransition.duration);
    await tester.pump(DitherTransition.duration);

    final rows = tester.widgetList<AppSkeleton>(find.byType(AppSkeleton));
    expect(rows.every((row) => !row.enabled), isTrue);
    expect(find.text('Solo Leveling'), findsOneWidget);
    expect(find.textContaining('anime title'), findsNothing);
  });

  testWidgets('shows search field and anime cards when loading succeeds', (
    tester,
  ) async {
    await _pumpCatalog(
      tester,
      _SuccessAnimeListRepository(
        initialResult: _withHasMore(_pageOneResult, false),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search anime'), findsOneWidget);
    expect(find.text('Filter & Sort'), findsOneWidget);
    expect(find.text('Solo Leveling'), findsOneWidget);
    expect(find.textContaining('TV · '), findsWidgets);
  });

  testWidgets('starts a new search after debounce', (tester) async {
    final repository = _TrackingAnimeListRepository(
      resultsByQuery: {'': _pageOneResult, 'fullmetal': _searchResult},
    );
    await _pumpCatalog(tester, repository);

    await tester.enterText(find.byType(TextField), 'fullmetal');
    await tester.pump(const Duration(milliseconds: 300));
    expect(_firstPages(repository, 'fullmetal'), 0);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(_firstPages(repository, 'fullmetal'), 1);
    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);
  });

  testWidgets('shows empty state for an empty search result', (tester) async {
    await _pumpCatalog(
      tester,
      _TrackingAnimeListRepository(
        resultsByQuery: {
          '': _pageOneResult,
          'missing': const AnimeListPageResult(
            items: [],
            page: 1,
            hasMore: false,
            query: 'missing',
          ),
        },
      ),
    );

    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.text('No anime found for your search.'), findsOneWidget);
  });

  testWidgets('a new order dissolves the heading into its new word', (
    tester,
  ) async {
    final bloc = await _pumpCatalog(
      tester,
      _TrackingAnimeListRepository(resultsByQuery: {'': _pageOneResult}),
    );

    bloc.add(const AnimeListCriteriaApplied(sort: AnimeListSortOption.score));
    await tester.pump();
    await tester.pump(DitherTransition.duration ~/ 2);
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Top rated'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Popular'), findsNothing);
    expect(find.text('Top rated'), findsOneWidget);
  });

  testWidgets('a card highlights only inside the list', (tester) async {
    await _pumpCatalog(
      tester,
      _TrackingAnimeListRepository(resultsByQuery: {'': _pageOneResult}),
    );

    // Ink paints on the nearest Material: it must scroll, and be clipped,
    // with the card rather than sit under the whole page.
    final ink = find
        .descendant(
          of: find.byType(AnimeCard).first,
          matching: find.byType(InkWell),
        )
        .first;
    final inkMaterial = tester
        .element(ink)
        .findAncestorWidgetOfExactType<Material>();
    final materialInList = find.descendant(
      of: find.byType(ListView).first,
      matching: find.byWidget(inkMaterial!),
    );
    expect(materialInList, findsOneWidget);
  });

  testWidgets('focusing shows recent searches without moving the catalog', (
    tester,
  ) async {
    setTestWindowSize(tester, TestWindowSizes.phone);
    await _pumpCatalog(
      tester,
      _TrackingAnimeListRepository(resultsByQuery: {'': _pageOneResult}),
    );
    expect(_catalogOffset(tester), 0);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    final inSearch = _catalogOffset(tester);
    expect(inSearch, 0);
    expect(find.byKey(const Key('catalog_recent_searches')), findsOneWidget);
    expect(find.text('Popular'), findsNothing);
    expect(find.text('Recent searches'), findsNothing);
    final empty = find.text('Your recent searches will appear here.');
    final icon = find.byWidgetPredicate(
      (widget) => widget is PixelIcon && widget.size == 42,
    );
    final area = tester.getRect(
      find.byKey(const Key('catalog_recent_searches')),
    );
    final textRect = tester.getRect(empty);
    final iconRect = tester.getRect(icon);
    expect(textRect.center.dx, closeTo(area.center.dx, 1));
    expect((iconRect.top + textRect.bottom) / 2, closeTo(area.center.dy, 1));
    expect(find.byKey(SearchToolbar.cancelButtonKey), findsOneWidget);

    // Typing a letter and taking it back changes the grid, not the page.
    await tester.enterText(find.byType(TextField), 'f');
    await tester.pump();
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(_catalogOffset(tester), inSearch);
    expect(find.byKey(SearchToolbar.cancelButtonKey), findsOneWidget);
  });

  testWidgets('results come over the catalog and leave it as it was', (
    tester,
  ) async {
    final repository = _TrackingAnimeListRepository(
      resultsByQuery: {'': _pageOneResult, 'fullmetal': _searchResult},
    );
    await _pumpCatalog(tester, repository);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'fullmetal');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(
      find.byType(RecentSearches),
      findsOneWidget,
      reason: 'history is still dissolving',
    );
    await tester.pumpAndSettle();
    expect(find.byType(RecentSearches), findsNothing);
    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);
    expect(find.text('Solo Leveling'), findsNothing);

    await tester.tap(find.byKey(SearchField.clearButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog_recent_searches')), findsOneWidget);
    expect(find.text('Solo Leveling'), findsNothing);
    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsNothing);
    // The catalog was never fetched again.
    expect(_firstPages(repository, ''), 1);
  });

  testWidgets('Cancel leaves search and brings the header back', (
    tester,
  ) async {
    setTestWindowSize(tester, TestWindowSizes.phone);
    await _pumpCatalog(
      tester,
      _TrackingAnimeListRepository(
        resultsByQuery: {'': _pageOneResult, 'fullmetal': _searchResult},
      ),
    );

    await tester.enterText(find.byType(TextField), 'fullmetal');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SearchToolbar.cancelButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(SearchToolbar.cancelButtonKey), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(_catalogOffset(tester), 0);
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Solo Leveling'), findsOneWidget);
  });

  testWidgets('Escape leaves search on wide windows', (tester) async {
    setTestWindowSize(tester, TestWindowSizes.desktop);
    await _pumpCatalog(
      tester,
      _TrackingAnimeListRepository(resultsByQuery: {'': _pageOneResult}),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.byKey(SearchToolbar.cancelButtonKey), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isFalse,
    );
    expect(_catalogOffset(tester), 0);
  });

  testWidgets('sort and filters narrow search results too', (tester) async {
    final repository = _TrackingAnimeListRepository(
      resultsByQuery: {'': _pageOneResult, 'fullmetal': _searchResult},
    );
    final bloc = await _pumpCatalog(tester, repository);

    bloc.add(
      const AnimeListCriteriaApplied(
        sort: AnimeListSortOption.score,
        filters: AnimeListFilters(kinds: {AnimeKindFilter.movie}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'fullmetal');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    final search = repository.calls.lastWhere(
      (call) => call.query.search == 'fullmetal',
    );
    expect(search.query.sort, AnimeListSortOption.score);
    expect(search.query.filters.kinds, {AnimeKindFilter.movie});
    expect(find.byTooltip('Remove “Movie” filter'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('opens the filter & sort panel with its controls', (
    tester,
  ) async {
    await _pumpCatalog(
      tester,
      _SuccessAnimeListRepository(initialResult: _pageOneResult),
    );

    await tester.tap(find.text('Filter & Sort'));
    await tester.pumpAndSettle();

    expect(find.text('SORT'), findsOneWidget);
    expect(find.text('TYPE'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('Popularity'), findsOneWidget);
    expect(find.text('Score'), findsOneWidget);
    expect(find.text('Aired On'), findsOneWidget);
    expect(find.text('Show results'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
  });

  testWidgets('applies filters and sort from the filter & sort panel', (
    tester,
  ) async {
    final repository = _TrackingAnimeListRepository(
      resultsByQuery: {'': _pageOneResult},
    );
    await _pumpCatalog(tester, repository);

    await tester.tap(find.text('Filter & Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Score'));
    await tester.tap(find.text('Movie'));
    await tester.tap(find.text('Released'));
    await tester.tap(find.text('Show results'));
    await tester.pumpAndSettle();

    expect(_firstPages(repository, ''), 2);
    expect(repository.calls.last.query.sort, AnimeListSortOption.score);
    expect(repository.calls.last.query.filters.kinds, {AnimeKindFilter.movie});
    expect(repository.calls.last.query.filters.statuses, {
      AnimeStatusFilter.released,
    });
  });

  testWidgets('reset returns criteria to default values', (tester) async {
    final repository = _TrackingAnimeListRepository(
      resultsByQuery: {'': _pageOneResult},
    );
    await _pumpCatalog(tester, repository);

    await tester.tap(find.text('Filter & Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Score'));
    await tester.tap(find.text('Movie'));
    await tester.tap(find.text('Released'));
    await tester.tap(find.text('Reset'));
    await tester.tap(find.text('Show results'));
    await tester.pumpAndSettle();

    expect(repository.calls.last.query.sort, AnimeListSortOption.popularity);
    expect(repository.calls.last.query.filters, const AnimeListFilters());
  });

  testWidgets('recent queries reopen a search and can be deleted', (
    tester,
  ) async {
    final repository = _TrackingAnimeListRepository(
      resultsByQuery: {'': _pageOneResult, 'fullmetal': _searchResult},
    );
    await _pumpCatalog(tester, repository);
    final history = tester
        .element(find.byType(TextField))
        .read<SearchHistoryCubit>();
    history.record('fullmetal');
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog_recent_searches')), findsOneWidget);
    await tester.tap(find.text('fullmetal'));
    await tester.pumpAndSettle();
    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);
    expect(_firstPages(repository, 'fullmetal'), 1);
    await tester.tap(find.byKey(SearchField.clearButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove “fullmetal”'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(history.state, isEmpty);
    expect(
      find.text('fullmetal'),
      findsOneWidget,
      reason: 'the removed query is still dissolving',
    );
    await tester.pumpAndSettle();
    expect(find.text('fullmetal'), findsNothing);
    expect(find.text('Your recent searches will appear here.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'fullmetal');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(history.state, ['fullmetal']);
  });

  testWidgets('individual chips and reset preserve the chosen sort', (
    tester,
  ) async {
    final repository = _TrackingAnimeListRepository(
      resultsByQuery: {'': _pageOneResult},
    );
    final bloc = await _pumpCatalog(tester, repository);
    bloc.add(
      const AnimeListCriteriaApplied(
        sort: AnimeListSortOption.score,
        filters: AnimeListFilters(
          kinds: {AnimeKindFilter.tv, AnimeKindFilter.movie},
          statuses: {AnimeStatusFilter.released},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byTooltip('Remove “TV” filter')).height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.text('TV'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('TV'),
      findsOneWidget,
      reason: 'only the removed chip dissolves',
    );
    await tester.pumpAndSettle();
    expect(find.text('TV'), findsNothing);
    expect(bloc.state.sort, AnimeListSortOption.score);
    expect(bloc.state.filters.kinds, {AnimeKindFilter.movie});
    expect(bloc.state.filters.statuses, {AnimeStatusFilter.released});
    expect(bloc.state.filters.activeCount, 2);
    await tester.tap(find.text('Reset'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 321));
    await tester.pump();
    expect(find.byKey(const Key('catalog_active_filters')), findsNothing);
    await tester.pumpAndSettle();
    expect(bloc.state.filters.hasAny, isFalse);
    expect(bloc.state.sort, AnimeListSortOption.score);
    expect(find.byKey(const Key('catalog_active_filters')), findsNothing);
    bloc.add(
      const AnimeListCriteriaApplied(
        filters: AnimeListFilters(kinds: {AnimeKindFilter.tv}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('TV'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 321));
    await tester.pump();
    expect(bloc.state.filters.hasAny, isFalse);
    expect(find.byKey(const Key('catalog_active_filters')), findsNothing);
  });

  testWidgets('a 320 wide phone keeps two poster columns', (tester) async {
    setTestWindowSize(tester, const Size(320, 760));
    await _pumpCatalog(
      tester,
      const _SuccessAnimeListRepository(initialResult: _pageOneResult),
    );
    final cards = find.byType(AnimeCard);
    expect(
      tester.getTopLeft(cards.at(0)).dy,
      tester.getTopLeft(cards.at(1)).dy,
    );
    expect(
      tester.getSize(cards.first).width,
      lessThan(tester.getSize(find.byType(AnimeListView)).width / 2),
    );
  });

  testWidgets(
    'empty search resets filters while retaining the query and sort',
    (tester) async {
      final repository = _TrackingAnimeListRepository(
        resultsByQuery: {
          '': _pageOneResult,
          'absent': const AnimeListPageResult(
            items: [],
            page: 1,
            hasMore: false,
            query: 'absent',
          ),
        },
      );
      final bloc = await _pumpCatalog(tester, repository);
      bloc.add(
        const AnimeListCriteriaApplied(
          sort: AnimeListSortOption.score,
          filters: AnimeListFilters(statuses: {AnimeStatusFilter.ongoing}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'absent');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('Reset filters'), findsOneWidget);
      await tester.tap(find.text('Reset filters'));
      await tester.pumpAndSettle();
      expect(bloc.state.filters.hasAny, isFalse);
      expect(bloc.state.sort, AnimeListSortOption.score);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'absent',
      );
      expect(
        repository.calls
            .lastWhere((call) => call.query.search == 'absent')
            .query
            .filters
            .hasAny,
        isFalse,
      );
    },
  );

  for (final searching in [false, true]) {
    testWidgets(
      'filter chips scroll to screen edges (${searching ? 'search' : 'catalog'})',
      (tester) async {
        setTestWindowSize(tester, const Size(320, 760));
        final bloc = await _pumpCatalog(
          tester,
          const _SuccessAnimeListRepository(initialResult: _pageOneResult),
        );
        bloc.add(
          AnimeListCriteriaApplied(
            filters: AnimeListFilters(
              kinds: const {AnimeKindFilter.tv},
              genres: {
                for (var i = 0; i < 8; i++)
                  AnimeGenre(
                    id: '$i',
                    name: 'Genre $i',
                    russian: '',
                    kind: AnimeGenreKind.genre,
                  ),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (searching) {
          await tester.tap(find.byType(TextField));
          await tester.pumpAndSettle();
        }
        final filters = find.byKey(const Key('catalog_active_filters'));
        final viewport = tester.getRect(filters);
        final first = find.byTooltip('Remove “TV” filter');
        final firstBounds = tester.getRect(first);
        final inset = tester.getTopLeft(find.byType(TextField)).dx;
        expect(viewport.left, 0);
        expect(viewport.right, 320);
        expect(firstBounds.left, inset);
        for (var i = 0; i < 8; i++) {
          expect(
            tester
                .getRect(find.byTooltip('Remove “Genre $i” filter'))
                .center
                .dy,
            firstBounds.center.dy,
          );
        }
        final scroll = tester
            .state<ScrollableState>(
              find.descendant(of: filters, matching: find.byType(Scrollable)),
            )
            .position;
        scroll.jumpTo(firstBounds.right - 10);
        await tester.pumpAndSettle();
        expect(tester.getRect(first).right, closeTo(10, 0.01));
        await tester.tapAt(Offset(4, firstBounds.center.dy));
        await tester.pumpAndSettle();
        expect(bloc.state.filters.kinds, isEmpty);
        expect(bloc.state.filters.genres, hasLength(8));

        final before = scroll.pixels;
        await tester.dragFrom(
          Offset(4, firstBounds.center.dy),
          const Offset(-80, 0),
        );
        await tester.pumpAndSettle();
        expect(scroll.pixels, greaterThan(before));
        scroll.jumpTo(scroll.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('Reset')).right,
          closeTo(viewport.right - inset, 0.01),
        );
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();
        expect(bloc.state.filters.hasAny, isFalse);
        expect(filters, findsNothing);
      },
    );
  }

  testWidgets('many applied filters leave search usable on a small phone', (
    tester,
  ) async {
    setTestWindowSize(tester, const Size(320, 600));
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final bloc = await _pumpCatalog(
      tester,
      const _SuccessAnimeListRepository(initialResult: _pageOneResult),
    );
    bloc.add(
      AnimeListCriteriaApplied(
        filters: AnimeListFilters(
          genres: {
            for (var i = 0; i < 30; i++)
              AnimeGenre(
                id: '$i',
                name: 'Genre $i',
                russian: '',
                kind: AnimeGenreKind.genre,
              ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog_recent_searches')), findsOneWidget);
    expect(find.byKey(SearchToolbar.cancelButtonKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty filtered results retain removable filters', (
    tester,
  ) async {
    final bloc = await _pumpCatalog(
      tester,
      const _SuccessAnimeListRepository(
        initialResult: AnimeListPageResult(
          items: [],
          page: 1,
          hasMore: false,
          query: '',
        ),
      ),
    );
    bloc.add(
      const AnimeListCriteriaApplied(
        filters: AnimeListFilters(statuses: {AnimeStatusFilter.ongoing}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove “Ongoing” filter'), findsOneWidget);
    expect(find.text('Reset filters'), findsOneWidget);
    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    expect(bloc.state.filters.hasAny, isFalse);
  });

  testWidgets('loads the next page near the end of the list', (tester) async {
    final repository = _TrackingAnimeListRepository(
      resultsByQuery: {'': _withHasMore(_pageOneResult, true)},
      pagedResults: {2: _pageTwoResult},
    );
    final bloc = AnimeListBloc(repository: repository);

    await tester.pumpWidget(
      _wrapWithApp(
        SizedBox(
          height: 500,
          child: BlocProvider.value(
            value: bloc..add(const AnimeListStarted()),
            child: const Scaffold(body: AnimeListView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.calls.any((call) => call.query.page == 2), isTrue);
  });

  for (final watched in const [false, true]) {
    testWidgets(
      watched
          ? 'a failed catalog keeps Continue watching available from its button'
          : 'a failed catalog without history is only the error',
      (tester) async {
        final history = WatchProgressCubit(
          repository: FixedWatchProgressRepository([
            if (watched) _watchProgress,
          ]),
        )..load();
        addTearDown(history.close);
        final bloc = AnimeListBloc(repository: _FailingAnimeListRepository())
          ..add(const AnimeListStarted());
        addTearDown(bloc.close);

        await tester.pumpWidget(
          _wrapWithApp(
            MultiBlocProvider(
              providers: [
                BlocProvider.value(value: history),
                BlocProvider.value(value: bloc),
              ],
              child: const Scaffold(body: AnimeListView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Unable to load anime list.'), findsOneWidget);
        expect(find.text('Try Again'), findsOneWidget);
        expect(
          find.byKey(ContinueWatchingButton.buttonKey),
          watched ? findsOneWidget : findsNothing,
        );
        if (watched) {
          await tester.tap(find.byKey(ContinueWatchingButton.buttonKey));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('continue_watching_abc')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('shows load more error and keeps loaded items', (tester) async {
    final repository = _LoadMoreFailureAnimeListRepository(
      initialResult: _singleItemResult,
    );
    final bloc = AnimeListBloc(repository: repository);

    await tester.pumpWidget(
      _wrapWithApp(
        SizedBox(
          height: 500,
          child: BlocProvider.value(
            value: bloc..add(const AnimeListStarted()),
            child: const Scaffold(body: AnimeListView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    bloc.add(const AnimeListNextPageRequested());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(AnimeCard), findsWidgets);
    // The footer sits under the heading and the covers.
    await tester.dragUntilVisible(
      find.text('Unable to load more anime.'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.text('Unable to load more anime.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });

  for (final entry in TestWindowSizes.all.entries) {
    testWidgets('lays out the catalog without overflow on ${entry.key}', (
      tester,
    ) async {
      setTestWindowSize(tester, entry.value);
      final bloc = AnimeListBloc(
        repository: _SuccessAnimeListRepository(
          initialResult: _withHasMore(_pageOneResult, false),
        ),
      );

      await tester.pumpWidget(
        _wrapWithApp(
          BlocProvider.value(
            value: bloc..add(const AnimeListStarted()),
            child: const AnimeListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final first = tester.getTopLeft(find.text('Solo Leveling'));
      final second = tester.getTopLeft(
        find.text("Frieren: Beyond Journey's End"),
      );
      final search = tester.getRect(find.byType(TextField));
      // Covers sit side by side even on phones, with the filters button on
      // the search field's row.
      expect(second.dy, first.dy);
      expect(search.width, lessThanOrEqualTo(AdaptiveContentWidth.form));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('requests the next page when a wide grid fits on screen', (
    tester,
  ) async {
    setTestWindowSize(tester, TestWindowSizes.desktop);
    final repository = _TrackingAnimeListRepository(
      resultsByQuery: {'': _singleItemResult},
      pagedResults: {2: _pageTwoResult},
    );
    await _pumpCatalog(tester, repository);

    expect(repository.calls.map((call) => call.query.page), [1, 2]);
    expect(find.text('Steins;Gate'), findsOneWidget);
  });
}

/// The app around [child], with search results served by [search].
Widget _wrapWithApp(Widget child, {AnimeListRepository? search}) {
  return testApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AnimeSearchBloc(
            repository: search ?? _PendingAnimeListRepository(),
          ),
        ),
        BlocProvider(
          create: (_) => SearchHistoryCubit(repository: _HistoryRepository()),
        ),
      ],
      child: child,
    ),
  );
}

/// The catalog page with [repository] behind both the catalog and search.
Future<AnimeListBloc> _pumpCatalog(
  WidgetTester tester,
  AnimeListRepository repository,
) async {
  final bloc = AnimeListBloc(repository: repository)
    ..add(const AnimeListStarted());
  await tester.pumpWidget(
    _wrapWithApp(
      BlocProvider.value(value: bloc, child: const AnimeListPage()),
      search: repository,
    ),
  );
  await tester.pumpAndSettle();
  return bloc;
}

/// The catalog is the first list; search results stack over it.
double _catalogOffset(WidgetTester tester) => tester
    .widget<ListView>(find.byType(ListView, skipOffstage: false).first)
    .controller!
    .offset;

/// First-page fetches for [search]: the catalog's own for an empty one.
int _firstPages(_TrackingAnimeListRepository repository, String search) =>
    repository.calls
        .where((call) => call.query.page == 1 && call.query.search == search)
        .length;

/// Answers with [answer], which by default never completes.
class _PendingAnimeListRepository implements AnimeListRepository {
  _PendingAnimeListRepository([Future<AnimeListPageResult>? answer])
    : answer = answer ?? Completer<AnimeListPageResult>().future;

  final Future<AnimeListPageResult> answer;

  @override
  Future<AnimeListPageResult> fetchAnimePage({required AnimeListQuery query}) =>
      answer;
}

class _SuccessAnimeListRepository implements AnimeListRepository {
  const _SuccessAnimeListRepository({required this.initialResult});

  final AnimeListPageResult initialResult;

  @override
  Future<AnimeListPageResult> fetchAnimePage({
    required AnimeListQuery query,
  }) async {
    return initialResult;
  }
}

class _TrackingAnimeListRepository implements AnimeListRepository {
  _TrackingAnimeListRepository({
    required this.resultsByQuery,
    this.pagedResults = const {},
  });

  final Map<String, AnimeListPageResult> resultsByQuery;
  final Map<int, AnimeListPageResult> pagedResults;
  final List<_RepositoryCall> calls = [];

  @override
  Future<AnimeListPageResult> fetchAnimePage({
    required AnimeListQuery query,
  }) async {
    calls.add(_RepositoryCall(query: query));

    if (query.page > 1) {
      return pagedResults[query.page]!;
    }

    return resultsByQuery[query.search]!;
  }
}

class _LoadMoreFailureAnimeListRepository implements AnimeListRepository {
  const _LoadMoreFailureAnimeListRepository({
    this.initialResult = _pageOneResult,
  });

  final AnimeListPageResult initialResult;

  @override
  Future<AnimeListPageResult> fetchAnimePage({
    required AnimeListQuery query,
  }) async {
    if (query.page == 1) {
      return _withHasMore(initialResult, true);
    }

    throw Exception('Load more failure');
  }
}

AnimeListPageResult _withHasMore(AnimeListPageResult result, bool hasMore) =>
    AnimeListPageResult(
      items: result.items,
      page: result.page,
      hasMore: hasMore,
      query: result.query,
    );

class _RepositoryCall {
  const _RepositoryCall({required this.query});

  final AnimeListQuery query;
}

const _pageOneItems = [
  AnimeListItem(
    anime: AnimeSummary(
      id: '21',
      name: 'Solo Leveling',
      russian: 'Solo Leveling RU',
      kind: 'tv',
      score: 8.34,
      status: 'released',
      episodes: 12,
      episodesAired: 12,
      airedOn: '2024-01-07',
      posterUrl: 'https://shikimori.one/posters/52299/main.webp',
    ),
  ),
  AnimeListItem(
    anime: AnimeSummary(
      id: '22',
      name: 'Frieren: Beyond Journey\'s End',
      russian: 'Frieren RU',
      kind: 'tv',
      score: 9.27,
      status: 'released',
      episodes: 28,
      episodesAired: 28,
      airedOn: '2023-09-29',
      posterUrl: 'https://shikimori.one/posters/52991/main.webp',
    ),
  ),
  AnimeListItem(
    anime: AnimeSummary(
      id: '23',
      name: 'Death Note',
      russian: 'Death Note RU',
      kind: 'tv',
      score: 8.61,
      status: 'released',
      episodes: 37,
      episodesAired: 37,
      airedOn: '2006-10-04',
      posterUrl: 'https://shikimori.one/posters/1535/main.jpg',
    ),
  ),
  AnimeListItem(
    anime: AnimeSummary(
      id: '24',
      name: 'Hunter x Hunter (2011)',
      russian: 'Hunter x Hunter RU',
      kind: 'tv',
      score: 9.04,
      status: 'released',
      episodes: 148,
      episodesAired: 148,
      airedOn: '2011-10-02',
      posterUrl: 'https://shikimori.one/posters/11061/main.jpg',
    ),
  ),
  AnimeListItem(
    anime: AnimeSummary(
      id: '25',
      name: 'Steins;Gate 0',
      russian: 'Steins;Gate 0 RU',
      kind: 'tv',
      score: 8.54,
      status: 'released',
      episodes: 23,
      episodesAired: 23,
      airedOn: '2018-04-12',
      posterUrl: 'https://shikimori.one/posters/30484/main.jpg',
    ),
  ),
  AnimeListItem(
    anime: AnimeSummary(
      id: '26',
      name: 'Mob Psycho 100',
      russian: 'Mob Psycho 100 RU',
      kind: 'tv',
      score: 8.49,
      status: 'released',
      episodes: 12,
      episodesAired: 12,
      airedOn: '2016-07-12',
      posterUrl: 'https://shikimori.one/posters/32182/main.jpg',
    ),
  ),
];

const _singleItem = AnimeListItem(
  anime: AnimeSummary(
    id: '21',
    name: 'Solo Leveling',
    russian: 'Solo Leveling RU',
    kind: 'tv',
    score: 8.34,
    status: 'released',
    episodes: 12,
    episodesAired: 12,
    airedOn: '2024-01-07',
    posterUrl: 'https://shikimori.one/posters/52299/main.webp',
  ),
);

const _pageTwoItems = [
  AnimeListItem(
    anime: AnimeSummary(
      id: '27',
      name: 'Steins;Gate',
      russian: 'Steins;Gate RU',
      kind: 'tv',
      score: 9.07,
      status: 'released',
      episodes: 24,
      episodesAired: 24,
      airedOn: '2011-04-06',
      posterUrl: 'https://shikimori.one/posters/9253/main.jpg',
    ),
  ),
];

const _searchItems = [
  AnimeListItem(
    anime: AnimeSummary(
      id: '5114',
      name: 'Fullmetal Alchemist: Brotherhood',
      russian: 'Fullmetal Alchemist: Brotherhood RU',
      kind: 'tv',
      score: 9.12,
      status: 'released',
      episodes: 64,
      episodesAired: 64,
      airedOn: '2009-04-05',
      posterUrl: 'https://shikimori.one/posters/5114/main.jpg',
    ),
  ),
];

const _pageOneResult = AnimeListPageResult(
  items: _pageOneItems,
  page: 1,
  hasMore: true,
  query: '',
);

const _singleItemResult = AnimeListPageResult(
  items: [_singleItem],
  page: 1,
  hasMore: true,
  query: '',
);

const _pageTwoResult = AnimeListPageResult(
  items: _pageTwoItems,
  page: 2,
  hasMore: false,
  query: '',
);

const _searchResult = AnimeListPageResult(
  items: _searchItems,
  page: 1,
  hasMore: false,
  query: 'fullmetal',
);

class _FailingAnimeListRepository implements AnimeListRepository {
  @override
  Future<AnimeListPageResult> fetchAnimePage({
    required AnimeListQuery query,
  }) async {
    throw Exception('offline');
  }
}

final _watchProgress = WatchProgress(
  torrentKey: 'abc',
  fileIndex: 0,
  fileName: 'Episode 1.mkv',
  magnet: 'magnet:?xt=urn:btih:abc',
  sourceTitle: 'Release',
  position: const Duration(minutes: 10),
  duration: const Duration(minutes: 24),
  updatedAt: DateTime.utc(2026, 10, 8, 12),
  animeId: '5114',
  animeTitle: 'Fullmetal Alchemist: Brotherhood',
);

class _HistoryRepository implements SearchHistoryRepository {
  @override
  List<String> read() => const [];
  @override
  Future<void> save(List<String> queries) async {}
}
