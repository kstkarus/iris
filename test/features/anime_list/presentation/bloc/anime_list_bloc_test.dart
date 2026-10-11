import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_page_result.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_list_repository.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_state.dart';

void main() {
  group('AnimeListBloc', () {
    test('loads the first page on start', () async {
      final bloc = AnimeListBloc(
        repository: _FakeAnimeListRepository(
          handler: ({required query}) async => _pageOne(query),
        ),
      );

      expectLater(
        bloc.stream,
        emitsThrough(
          isA<AnimeListState>().having(
            (state) => state.items,
            'items',
            _pageOneItems,
          ),
        ),
      );

      bloc.add(const AnimeListStarted());
      await Future<void>.delayed(Duration.zero);
    });

    test('appends the next page when load more succeeds', () async {
      final bloc = AnimeListBloc(
        repository: _FakeAnimeListRepository(
          handler: ({required query}) async {
            if (query.page == 1) {
              return AnimeListPageResult(
                items: _pageOneItems,
                page: 1,
                hasMore: true,
                query: '',
              );
            }

            return AnimeListPageResult(
              items: _pageTwoItems,
              page: 2,
              hasMore: false,
              query: '',
            );
          },
        ),
      );

      bloc.add(const AnimeListStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AnimeListNextPageRequested());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.items, [..._pageOneItems, ..._pageTwoItems]);
      expect(bloc.state.page, 2);
      expect(bloc.state.hasMore, isFalse);
    });

    test('does not request the next page when hasMore is false', () async {
      var callCount = 0;
      final bloc = AnimeListBloc(
        repository: _FakeAnimeListRepository(
          handler: ({required query}) async {
            callCount++;
            return AnimeListPageResult(
              items: _pageOneItems,
              page: 1,
              hasMore: false,
              query: '',
            );
          },
        ),
      );

      bloc.add(const AnimeListStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AnimeListNextPageRequested());
      await Future<void>.delayed(Duration.zero);

      expect(callCount, 1);
    });

    test(
      'resets items and loads the first page for a new search query',
      () async {
        final bloc = AnimeListBloc(
          repository: _FakeAnimeListRepository(
            handler: ({required query}) async {
              if (query.search.isEmpty) {
                return AnimeListPageResult(
                  items: _pageOneItems,
                  page: 1,
                  hasMore: true,
                  query: '',
                );
              }

              return AnimeListPageResult(
                items: _searchItems,
                page: 1,
                hasMore: false,
                query: query.search,
              );
            },
          ),
        );

        bloc.add(const AnimeListStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AnimeListSearchChanged('fullmetal'));
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.items, _searchItems);
        expect(bloc.state.page, 1);
        expect(bloc.state.query, 'fullmetal');
        expect(bloc.state.hasMore, isFalse);
      },
    );

    test('clearing search restores the default list flow', () async {
      final bloc = AnimeListBloc(
        repository: _FakeAnimeListRepository(
          handler: ({required query}) async {
            if (query.search.isEmpty) {
              return AnimeListPageResult(
                items: _pageOneItems,
                page: 1,
                hasMore: true,
                query: '',
              );
            }

            return AnimeListPageResult(
              items: _searchItems,
              page: 1,
              hasMore: false,
              query: query.search,
            );
          },
        ),
      );

      bloc.add(const AnimeListSearchChanged('fullmetal'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AnimeListSearchCleared());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.items, _pageOneItems);
      expect(bloc.state.query, isEmpty);
      expect(bloc.state.hasMore, isTrue);
    });

    test('emits initial error when the first page fails', () async {
      final bloc = AnimeListBloc(
        repository: _FakeAnimeListRepository(
          handler: ({required query}) async {
            throw Exception('Initial failure');
          },
        ),
      );

      bloc.add(const AnimeListStarted());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.errorType, AnimeListErrorType.initial);
      expect(bloc.state.hasLoadedOnce, isFalse);
    });

    test('keeps loaded items when load more fails', () async {
      final bloc = AnimeListBloc(
        repository: _FakeAnimeListRepository(
          handler: ({required query}) async {
            if (query.page == 1) {
              return AnimeListPageResult(
                items: _pageOneItems,
                page: 1,
                hasMore: true,
                query: '',
              );
            }

            throw Exception('Load more failure');
          },
        ),
      );

      bloc.add(const AnimeListStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AnimeListNextPageRequested());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.items, _pageOneItems);
      expect(bloc.state.errorType, AnimeListErrorType.loadMore);
      expect(bloc.state.hasLoadedOnce, isTrue);
    });

    test(
      'ignores stale search results from an older request session',
      () async {
        final firstSearchCompleter = Completer<AnimeListPageResult>();
        final secondSearchCompleter = Completer<AnimeListPageResult>();

        final bloc = AnimeListBloc(
          repository: _FakeAnimeListRepository(
            handler: ({required query}) {
              if (query.search == 'first') {
                return firstSearchCompleter.future;
              }

              if (query.search == 'second') {
                return secondSearchCompleter.future;
              }

              return Future.value(
                AnimeListPageResult(
                  items: const [],
                  page: 1,
                  hasMore: false,
                  query: '',
                ),
              );
            },
          ),
        );

        bloc.add(const AnimeListSearchChanged('first'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AnimeListSearchChanged('second'));
        await Future<void>.delayed(Duration.zero);

        secondSearchCompleter.complete(
          AnimeListPageResult(
            items: _searchItems,
            page: 1,
            hasMore: false,
            query: 'second',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        firstSearchCompleter.complete(
          AnimeListPageResult(
            items: _pageOneItems,
            page: 1,
            hasMore: false,
            query: 'first',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.query, 'second');
        expect(bloc.state.items, _searchItems);
      },
    );

    test('applies filters and reloads the first page', () async {
      AnimeListQuery? capturedQuery;
      final bloc = AnimeListBloc(
        repository: _FakeAnimeListRepository(
          handler: ({required query}) async {
            capturedQuery = query;
            return _pageOne(query);
          },
        ),
      );

      bloc.add(
        const AnimeListCriteriaApplied(
          filters: AnimeListFilters(
            kinds: {AnimeKindFilter.movie},
            statuses: {AnimeStatusFilter.released},
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(capturedQuery?.page, 1);
      expect(capturedQuery?.filters.kinds, {AnimeKindFilter.movie});
      expect(capturedQuery?.filters.statuses, {AnimeStatusFilter.released});
      expect(bloc.state.filters.kinds, {AnimeKindFilter.movie});
    });

    test('clearing search keeps active filters and sort', () async {
      late AnimeListQuery lastQuery;
      final bloc = AnimeListBloc(
        repository: _FakeAnimeListRepository(
          handler: ({required query}) async {
            lastQuery = query;
            return _pageOne(query);
          },
        ),
      );

      bloc.add(
        const AnimeListCriteriaApplied(
          sort: AnimeListSortOption.score,
          filters: AnimeListFilters(
            kinds: {AnimeKindFilter.ova},
            statuses: {AnimeStatusFilter.announced},
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AnimeListSearchChanged('test'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AnimeListSearchCleared());
      await Future<void>.delayed(Duration.zero);

      expect(lastQuery.search, isEmpty);
      expect(lastQuery.sort, AnimeListSortOption.score);
      expect(lastQuery.filters.kinds, {AnimeKindFilter.ova});
      expect(lastQuery.filters.statuses, {AnimeStatusFilter.announced});
    });

    test('resets criteria back to default catalog state', () async {
      late AnimeListQuery lastQuery;
      final bloc = AnimeListBloc(
        repository: _FakeAnimeListRepository(
          handler: ({required query}) async {
            lastQuery = query;
            return _pageOne(query);
          },
        ),
      );

      bloc.add(
        const AnimeListCriteriaApplied(
          sort: AnimeListSortOption.score,
          filters: AnimeListFilters(
            kinds: {AnimeKindFilter.movie},
            statuses: {AnimeStatusFilter.ongoing},
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AnimeListCriteriaReset());
      await Future<void>.delayed(Duration.zero);

      expect(lastQuery.sort, AnimeListSortOption.popularity);
      expect(lastQuery.filters, const AnimeListFilters());
      expect(bloc.state.sort, AnimeListSortOption.popularity);
      expect(bloc.state.filters, const AnimeListFilters());
    });

    test('passes active filters and sort to the next page request', () async {
      final seenQueries = <AnimeListQuery>[];
      final bloc = AnimeListBloc(
        repository: _FakeAnimeListRepository(
          handler: ({required query}) async {
            seenQueries.add(query);
            return AnimeListPageResult(
              items: query.page == 1 ? _pageOneItems : _pageTwoItems,
              page: query.page,
              hasMore: query.page == 1,
              query: query.search,
            );
          },
        ),
      );

      bloc.add(
        const AnimeListCriteriaApplied(
          sort: AnimeListSortOption.score,
          filters: AnimeListFilters(
            kinds: {AnimeKindFilter.tv},
            statuses: {AnimeStatusFilter.released},
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AnimeListSearchChanged('gate'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AnimeListNextPageRequested());
      await Future<void>.delayed(Duration.zero);

      expect(seenQueries.last.page, 2);
      expect(seenQueries.last.search, 'gate');
      expect(seenQueries.last.sort, AnimeListSortOption.score);
      expect(seenQueries.last.filters.kinds, {AnimeKindFilter.tv});
      expect(seenQueries.last.filters.statuses, {AnimeStatusFilter.released});
    });

    for (final fails in [false, true]) {
      final outcome = fails ? 'fails' : 'arrives';
      test(
        'does not throw when closed before the first page $outcome',
        () async {
          var fetches = 0;
          final errors = await _collectUncaughtErrors(() async {
            final pending = Completer<AnimeListPageResult>();
            final bloc = AnimeListBloc(
              repository: _FakeAnimeListRepository(
                handler: ({required query}) {
                  fetches++;
                  return pending.future;
                },
              ),
            );

            bloc.add(const AnimeListStarted());
            await Future<void>.delayed(Duration.zero);
            await bloc.close();
            if (fails) {
              pending.completeError(Exception('Initial failure'));
            } else {
              pending.complete(
                AnimeListPageResult(
                  items: _pageOneItems,
                  page: 1,
                  hasMore: true,
                  query: '',
                ),
              );
            }
            await Future<void>.delayed(Duration.zero);
          });

          expect(fetches, 1);
          expect(errors, isEmpty);
        },
      );
    }

    test('signing out drops the list filters and reloads', () async {
      final queries = <AnimeListQuery>[];
      final bloc = AnimeListBloc(
        repository: _FakeAnimeListRepository(
          handler: ({required query}) async {
            queries.add(query);
            return AnimeListPageResult(
              items: _pageOneItems,
              page: 1,
              hasMore: false,
              query: '',
            );
          },
        ),
      );
      bloc
        ..add(const AnimeListAccountChanged(signedIn: true, reload: false))
        ..add(const AnimeListStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(
        const AnimeListCriteriaApplied(
          filters: AnimeListFilters(
            kinds: {AnimeKindFilter.tv},
            myList: {UserRateStatus.watching},
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      bloc.add(const AnimeListAccountChanged(signedIn: false, reload: false));
      await Future<void>.delayed(Duration.zero);

      expect(
        queries.last.filters,
        const AnimeListFilters(kinds: {AnimeKindFilter.tv}),
      );
      expect(bloc.state.filters.usesMyList, isFalse);
      await bloc.close();
    });

    test(
      'signing in or out reloads the list; a restored session does not',
      () async {
        var requests = 0;
        final bloc = AnimeListBloc(
          repository: _FakeAnimeListRepository(
            handler: ({required query}) async {
              requests++;
              return AnimeListPageResult(
                items: _pageOneItems,
                page: 1,
                hasMore: false,
                query: '',
              );
            },
          ),
        );

        bloc.add(const AnimeListStarted());
        await Future<void>.delayed(Duration.zero);
        expect(requests, 1);

        bloc.add(const AnimeListAccountChanged(signedIn: true, reload: false));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.signedIn, isTrue);
        expect(requests, 1);

        bloc.add(const AnimeListAccountChanged(signedIn: false));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.signedIn, isFalse);
        expect(requests, 2);

        bloc.add(const AnimeListAccountChanged(signedIn: false));
        await Future<void>.delayed(Duration.zero);
        expect(requests, 2);
        await bloc.close();
      },
    );
  });
}

/// Runs [body] in its own zone and returns the errors it leaves uncaught,
/// such as a failed `add` inside a fetch that nothing awaits. Create any
/// completer that [body] completes inside [body]: an error does not cross
/// zones, so one made outside would be reported as uncaught instead.
Future<List<Object>> _collectUncaughtErrors(
  Future<void> Function() body,
) async {
  final errors = <Object>[];
  await runZonedGuarded(body, (error, _) => errors.add(error));
  return errors;
}

/// [_pageOneItems] as the answer to [query], with more to come.
AnimeListPageResult _pageOne(AnimeListQuery query) {
  return AnimeListPageResult(
    items: _pageOneItems,
    page: query.page,
    hasMore: true,
    query: query.search,
  );
}

class _FakeAnimeListRepository implements AnimeListRepository {
  const _FakeAnimeListRepository({required this.handler});

  final Future<AnimeListPageResult> Function({required AnimeListQuery query})
  handler;

  @override
  Future<AnimeListPageResult> fetchAnimePage({required AnimeListQuery query}) {
    return handler(query: query);
  }
}

const _pageOneItems = [
  AnimeListItem(
    anime: AnimeSummary(
      id: '1',
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
];

const _pageTwoItems = [
  AnimeListItem(
    anime: AnimeSummary(
      id: '2',
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
