import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress_repository.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_page_result.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_list_repository.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_search_bloc.dart';
import 'package:iris/features/anime_list/presentation/pages/anime_list_page.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_card.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_list_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/search_field.dart';
import 'package:iris/shared/widgets/search_toolbar.dart';
import 'package:iris/shared/widgets/dither_transition.dart';

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
    final bloc = AnimeListBloc(repository: _CompleterAnimeListRepository(page));

    await tester.pumpWidget(
      _wrapWithApp(
        BlocProvider.value(
          value: bloc..add(const AnimeListStarted()),
          child: const Scaffold(body: AnimeListView()),
        ),
      ),
    );
    await tester.pump();

    page.complete(_pageOneResult);
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
    final bloc = AnimeListBloc(
      repository: _SuccessAnimeListRepository(initialResult: _pageOneResult),
    );

    await tester.pumpWidget(
      _wrapWithApp(
        BlocProvider.value(
          value: bloc..add(const AnimeListStarted()),
          child: const Scaffold(body: AnimeListView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

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

  testWidgets('focusing the field moves the header away once', (tester) async {
    setTestWindowSize(tester, TestWindowSizes.phone);
    await _pumpCatalog(
      tester,
      _TrackingAnimeListRepository(resultsByQuery: {'': _pageOneResult}),
    );
    expect(_catalogOffset(tester), 0);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    final inSearch = _catalogOffset(tester);
    expect(inSearch, greaterThan(0));
    expect(find.text('Popular'), findsNothing);
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

    await tester.enterText(find.byType(TextField), 'fullmetal');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);
    expect(find.text('Solo Leveling'), findsNothing);

    await tester.tap(find.byKey(SearchField.clearButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('Solo Leveling'), findsOneWidget);
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
    expect(find.byKey(SearchToolbar.cancelButtonKey), findsNothing);

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

    bloc.add(const AnimeListCriteriaApplied(sort: AnimeListSortOption.score));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'fullmetal');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    final search = repository.calls.lastWhere(
      (call) => call.query.search == 'fullmetal',
    );
    expect(search.query.sort, AnimeListSortOption.score);
  });

  testWidgets('opens bottom sheet with sort and filter controls', (
    tester,
  ) async {
    final bloc = AnimeListBloc(
      repository: _SuccessAnimeListRepository(initialResult: _pageOneResult),
    );

    await tester.pumpWidget(
      _wrapWithApp(
        BlocProvider.value(
          value: bloc..add(const AnimeListStarted()),
          child: const Scaffold(body: AnimeListView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter & Sort'));
    await tester.pumpAndSettle();

    expect(find.text('SORT'), findsOneWidget);
    expect(find.text('TYPE'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('Popularity'), findsOneWidget);
    expect(find.text('Score'), findsOneWidget);
    expect(find.text('Aired On'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
  });

  testWidgets('applies selected filters and sort from bottom sheet', (
    tester,
  ) async {
    final repository = _TrackingAnimeListRepository(
      resultsByQuery: {'': _pageOneResult},
    );
    final bloc = AnimeListBloc(repository: repository);

    await tester.pumpWidget(
      _wrapWithApp(
        BlocProvider.value(
          value: bloc..add(const AnimeListStarted()),
          child: const Scaffold(body: AnimeListView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter & Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Score'));
    await tester.tap(find.text('Movie'));
    await tester.tap(find.text('Released'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(repository.calls.length, 2);
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
    final bloc = AnimeListBloc(repository: repository);

    await tester.pumpWidget(
      _wrapWithApp(
        BlocProvider.value(
          value: bloc..add(const AnimeListStarted()),
          child: const Scaffold(body: AnimeListView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter & Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Score'));
    await tester.tap(find.text('Movie'));
    await tester.tap(find.text('Released'));
    await tester.tap(find.text('Reset'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(repository.calls.last.query.sort, AnimeListSortOption.popularity);
    expect(repository.calls.last.query.filters, const AnimeListFilters());
  });

  testWidgets('loads the next page near the end of the list', (tester) async {
    final repository = _TrackingAnimeListRepository(
      resultsByQuery: {'': _pageOneResult.copyWith(hasMore: true)},
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
          ? 'a failed catalog keeps Continue watching above the error'
          : 'a failed catalog without history is only the error',
      (tester) async {
        final history = WatchProgressCubit(
          repository: _StubWatchProgressRepository([
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
          find.byKey(const ValueKey('continue_watching_abc')),
          watched ? findsOneWidget : findsNothing,
        );
        if (watched) {
          expect(
            tester.getRect(find.text('Unable to load anime list.')).top,
            greaterThan(
              tester
                  .getRect(find.byKey(const ValueKey('continue_watching_abc')))
                  .bottom,
            ),
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
          initialResult: _pageOneResult.copyWith(hasMore: false),
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
      expect(search.width, lessThanOrEqualTo(560));
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
    final bloc = AnimeListBloc(repository: repository);

    await tester.pumpWidget(
      _wrapWithApp(
        BlocProvider.value(
          value: bloc..add(const AnimeListStarted()),
          child: const Scaffold(body: AnimeListView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.calls.map((call) => call.query.page), [1, 2]);
    expect(find.text('Steins;Gate'), findsOneWidget);
  });
}

/// The app around [child], with search results served by [search].
Widget _wrapWithApp(Widget child, {AnimeListRepository? search}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider(
      create: (_) =>
          AnimeSearchBloc(repository: search ?? _PendingAnimeListRepository()),
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
      BlocProvider.value(
        value: bloc,
        child: const Scaffold(body: AnimeListView()),
      ),
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

class _PendingAnimeListRepository implements AnimeListRepository {
  @override
  Future<AnimeListPageResult> fetchAnimePage({required AnimeListQuery query}) {
    return Completer<AnimeListPageResult>().future;
  }
}

class _CompleterAnimeListRepository implements AnimeListRepository {
  const _CompleterAnimeListRepository(this.page);

  final Completer<AnimeListPageResult> page;

  @override
  Future<AnimeListPageResult> fetchAnimePage({required AnimeListQuery query}) {
    return page.future;
  }
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
      return initialResult.copyWith(hasMore: true);
    }

    throw Exception('Load more failure');
  }
}

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

class _StubWatchProgressRepository implements WatchProgressRepository {
  const _StubWatchProgressRepository(this.items);

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
