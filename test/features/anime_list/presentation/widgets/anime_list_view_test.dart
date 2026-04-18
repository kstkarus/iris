import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_page_result.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_list_repository.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_card.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_list_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('shows a loader while anime are loading', (tester) async {
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

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
    expect(find.text('TV / Released'), findsWidgets);
  });

  testWidgets('starts a new search after debounce', (tester) async {
    final repository = _TrackingAnimeListRepository(
      resultsByQuery: {'': _pageOneResult, 'fullmetal': _searchResult},
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

    await tester.enterText(find.byType(TextField), 'fullmetal');
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.calls.length, 1);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(repository.calls.length, 2);
    expect(repository.calls.last.query.search, 'fullmetal');
    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);
  });

  testWidgets('shows empty state for an empty search result', (tester) async {
    final bloc = AnimeListBloc(
      repository: _SuccessAnimeListRepository(
        initialResult: const AnimeListPageResult(
          items: [],
          page: 1,
          hasMore: false,
          query: 'missing',
        ),
      ),
    );

    await tester.pumpWidget(
      _wrapWithApp(
        BlocProvider.value(
          value: bloc..add(const AnimeListSearchChanged('missing')),
          child: const Scaffold(body: AnimeListView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No anime found for your search.'), findsOneWidget);
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

    expect(find.text('Sort'), findsOneWidget);
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
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
    expect(find.text('Unable to load more anime.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });
}

Widget _wrapWithApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

class _PendingAnimeListRepository implements AnimeListRepository {
  @override
  Future<AnimeListPageResult> fetchAnimePage({required AnimeListQuery query}) {
    return Completer<AnimeListPageResult>().future;
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
    id: '21',
    name: 'Solo Leveling',
    russian: 'Solo Leveling RU',
    kind: 'tv',
    score: 8.34,
    status: 'released',
    episodes: 12,
    episodesAired: 12,
    airedOn: '2024-01-07',
    posterMainUrl: 'https://shikimori.one/posters/52299/main.webp',
  ),
  AnimeListItem(
    id: '22',
    name: 'Frieren: Beyond Journey\'s End',
    russian: 'Frieren RU',
    kind: 'tv',
    score: 9.27,
    status: 'released',
    episodes: 28,
    episodesAired: 28,
    airedOn: '2023-09-29',
    posterMainUrl: 'https://shikimori.one/posters/52991/main.webp',
  ),
  AnimeListItem(
    id: '23',
    name: 'Death Note',
    russian: 'Death Note RU',
    kind: 'tv',
    score: 8.61,
    status: 'released',
    episodes: 37,
    episodesAired: 37,
    airedOn: '2006-10-04',
    posterMainUrl: 'https://shikimori.one/posters/1535/main.jpg',
  ),
  AnimeListItem(
    id: '24',
    name: 'Hunter x Hunter (2011)',
    russian: 'Hunter x Hunter RU',
    kind: 'tv',
    score: 9.04,
    status: 'released',
    episodes: 148,
    episodesAired: 148,
    airedOn: '2011-10-02',
    posterMainUrl: 'https://shikimori.one/posters/11061/main.jpg',
  ),
  AnimeListItem(
    id: '25',
    name: 'Steins;Gate 0',
    russian: 'Steins;Gate 0 RU',
    kind: 'tv',
    score: 8.54,
    status: 'released',
    episodes: 23,
    episodesAired: 23,
    airedOn: '2018-04-12',
    posterMainUrl: 'https://shikimori.one/posters/30484/main.jpg',
  ),
  AnimeListItem(
    id: '26',
    name: 'Mob Psycho 100',
    russian: 'Mob Psycho 100 RU',
    kind: 'tv',
    score: 8.49,
    status: 'released',
    episodes: 12,
    episodesAired: 12,
    airedOn: '2016-07-12',
    posterMainUrl: 'https://shikimori.one/posters/32182/main.jpg',
  ),
];

const _singleItem = AnimeListItem(
  id: '21',
  name: 'Solo Leveling',
  russian: 'Solo Leveling RU',
  kind: 'tv',
  score: 8.34,
  status: 'released',
  episodes: 12,
  episodesAired: 12,
  airedOn: '2024-01-07',
  posterMainUrl: 'https://shikimori.one/posters/52299/main.webp',
);

const _pageTwoItems = [
  AnimeListItem(
    id: '27',
    name: 'Steins;Gate',
    russian: 'Steins;Gate RU',
    kind: 'tv',
    score: 9.07,
    status: 'released',
    episodes: 24,
    episodesAired: 24,
    airedOn: '2011-04-06',
    posterMainUrl: 'https://shikimori.one/posters/9253/main.jpg',
  ),
];

const _searchItems = [
  AnimeListItem(
    id: '5114',
    name: 'Fullmetal Alchemist: Brotherhood',
    russian: 'Fullmetal Alchemist: Brotherhood RU',
    kind: 'tv',
    score: 9.12,
    status: 'released',
    episodes: 64,
    episodesAired: 64,
    airedOn: '2009-04-05',
    posterMainUrl: 'https://shikimori.one/posters/5114/main.jpg',
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
