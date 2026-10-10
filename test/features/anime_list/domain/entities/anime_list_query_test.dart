import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/anime_list/domain/entities/anime_genre.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/entities/season_filter.dart';

void main() {
  test('serializes selected filters into GraphQL-friendly variables', () {
    const query = AnimeListQuery(
      page: 2,
      limit: 12,
      search: 'frieren',
      sort: AnimeListSortOption.score,
      filters: AnimeListFilters(
        kinds: {AnimeKindFilter.tv, AnimeKindFilter.movie},
        statuses: {AnimeStatusFilter.released, AnimeStatusFilter.ongoing},
      ),
    );

    expect(query.variables, {
      'page': 2,
      'limit': 12,
      'search': 'frieren',
      'order': 'ranked',
      'kind': 'tv,movie',
      'status': 'released,ongoing',
      'mylist': null,
      'genre': null,
      'season': null,
      'rating': null,
      'duration': null,
    });
  });

  test('omits empty filters instead of serializing blank values', () {
    const query = AnimeListQuery(page: 1, limit: 12);

    expect(query.variables, {
      'page': 1,
      'limit': 12,
      'search': null,
      'order': 'popularity',
      'kind': null,
      'status': null,
      'mylist': null,
      'genre': null,
      'season': null,
      'rating': null,
      'duration': null,
    });
  });

  test('serializes the list, genre, season, rating and length filters', () {
    final query = AnimeListQuery(
      page: 1,
      limit: 12,
      filters: AnimeListFilters(
        myList: {UserRateStatus.planned, UserRateStatus.watching},
        hideCompleted: true,
        genres: {
          AnimeGenre(
            id: '10',
            name: 'Fantasy',
            russian: '',
            kind: AnimeGenreKind.genre,
          ),
          AnimeGenre(
            id: '2',
            name: 'Adventure',
            russian: '',
            kind: AnimeGenreKind.genre,
          ),
        },
        seasons: {
          const SeasonFilter.year(2025),
          const SeasonFilter.decade(2010),
        },
        ratings: {AnimeRatingFilter.pg13, AnimeRatingFilter.g},
        durations: {AnimeDurationFilter.long},
      ),
    );

    final variables = query.variables;
    expect(variables['mylist'], 'planned,watching,!completed');
    expect(variables['genre'], '2,10');
    expect(variables['season'], '2010_2019,2025');
    expect(variables['rating'], 'g,pg_13');
    expect(variables['duration'], 'F');
  });

  test('signing out leaves the other filters as they are', () {
    const filters = AnimeListFilters(
      kinds: {AnimeKindFilter.tv},
      myList: {UserRateStatus.watching},
      hideCompleted: true,
    );

    expect(filters.usesMyList, isTrue);
    expect(
      filters.withoutMyList(),
      const AnimeListFilters(kinds: {AnimeKindFilter.tv}),
    );
  });
}
