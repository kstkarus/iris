import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';

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
    });
  });
}
