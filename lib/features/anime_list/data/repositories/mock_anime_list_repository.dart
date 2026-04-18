import 'package:iris/features/anime_list/data/datasources/mock_anime_list_data_source.dart';
import 'package:iris/features/anime_list/data/mappers/shikimori_anime_mapper.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_page_result.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_list_repository.dart';

class MockAnimeListRepository implements AnimeListRepository {
  const MockAnimeListRepository({required this.dataSource});

  final MockAnimeListDataSource dataSource;

  @override
  Future<AnimeListPageResult> fetchAnimePage({
    required AnimeListQuery query,
  }) async {
    final anime = await dataSource.fetchPopularAnime();
    final items =
        anime
            .map(mapShikimoriAnimeToDomain)
            .where(
              (item) =>
                  _matchesSearch(item, query.search) &&
                  _matchesFilters(item, query.filters),
            )
            .toList(growable: false)
          ..sort((left, right) => _compareBySort(query.sort, left, right));
    final startIndex = (query.page - 1) * query.limit;
    if (startIndex >= items.length) {
      return AnimeListPageResult(
        items: const [],
        page: query.page,
        hasMore: false,
        query: query.search,
      );
    }

    final endIndex = startIndex + query.limit > items.length
        ? items.length
        : startIndex + query.limit;
    final pageItems = items.sublist(startIndex, endIndex);

    return AnimeListPageResult(
      items: pageItems,
      page: query.page,
      hasMore: endIndex < items.length,
      query: query.search,
    );
  }
}

bool _matchesSearch(AnimeListItem item, String? search) {
  final normalizedQuery = search?.trim().toLowerCase();
  if (normalizedQuery == null || normalizedQuery.isEmpty) {
    return true;
  }

  return item.name.toLowerCase().contains(normalizedQuery) ||
      item.russian.toLowerCase().contains(normalizedQuery);
}

bool _matchesFilters(AnimeListItem item, AnimeListFilters filters) {
  final matchesKind =
      filters.kinds.isEmpty ||
      filters.kinds.any((kind) => kind.apiValue == item.kind);
  final matchesStatus =
      filters.statuses.isEmpty ||
      filters.statuses.any((status) => status.apiValue == item.status);

  return matchesKind && matchesStatus;
}

int _compareBySort(
  AnimeListSortOption sort,
  AnimeListItem left,
  AnimeListItem right,
) {
  switch (sort) {
    case AnimeListSortOption.popularity:
      return 0;
    case AnimeListSortOption.score:
      return right.score.compareTo(left.score);
    case AnimeListSortOption.airedOn:
      return right.airedOn.compareTo(left.airedOn);
  }
}
