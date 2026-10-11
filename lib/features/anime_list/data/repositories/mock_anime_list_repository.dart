import 'package:iris/entities/user_rate/data/mock_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/anime_list/data/datasources/mock_anime_list_data_source.dart';
import 'package:iris/features/anime_list/data/mappers/shikimori_anime_mapper.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_page_result.dart';
import 'package:iris/features/anime_list/domain/entities/season_filter.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_list_repository.dart';
import 'package:iris/shared/utils/incomplete_date.dart';

/// The mock catalog. It filters by kind, status, season (by year) and the
/// user's list; its titles carry no genres, ratings or lengths, so those
/// filters keep everything.
class MockAnimeListRepository implements AnimeListRepository {
  const MockAnimeListRepository({required this.dataSource, this.userRates});

  final MockAnimeListDataSource dataSource;

  /// The mock user's list, for the list filter and the cards.
  final MockUserRateRepository? userRates;

  @override
  Future<AnimeListPageResult> fetchAnimePage({
    required AnimeListQuery query,
  }) async {
    final anime = await dataSource.fetchPopularAnime();
    final items =
        anime
            .map(mapShikimoriAnimeToDomain)
            .map(_withUserRate)
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

  AnimeListItem _withUserRate(AnimeListItem item) {
    final rate = userRates?.rates[item.anime.id];
    if (rate == null) return item;
    return AnimeListItem(anime: item.anime, userRate: rate);
  }
}

bool _matchesSearch(AnimeListItem item, String? search) {
  final normalizedQuery = search?.trim().toLowerCase();
  if (normalizedQuery == null || normalizedQuery.isEmpty) {
    return true;
  }

  return item.anime.name.toLowerCase().contains(normalizedQuery) ||
      item.anime.russian.toLowerCase().contains(normalizedQuery);
}

bool _matchesFilters(AnimeListItem item, AnimeListFilters filters) {
  final matchesKind =
      filters.kinds.isEmpty ||
      filters.kinds.any((kind) => kind.apiValue == item.anime.kind);
  final matchesStatus =
      filters.statuses.isEmpty ||
      filters.statuses.any((status) => status.apiValue == item.anime.status);

  final status = item.userRate?.status;
  final matchesMyList =
      (filters.myList.isEmpty || filters.myList.contains(status)) &&
      (!filters.hideCompleted || status != UserRateStatus.completed);
  final year = yearOfIsoDate(item.anime.airedOn);
  final matchesSeason =
      filters.seasons.isEmpty ||
      (year != null &&
          filters.seasons.any((season) => _seasonHasYear(season, year)));

  return matchesKind && matchesStatus && matchesMyList && matchesSeason;
}

bool _seasonHasYear(SeasonFilter season, int year) => switch (season.kind) {
  SeasonFilterKind.season || SeasonFilterKind.year => season.year == year,
  SeasonFilterKind.decade => year >= season.year && year < season.year + 10,
  SeasonFilterKind.before2000 => year < 2000,
};

int _compareBySort(
  AnimeListSortOption sort,
  AnimeListItem left,
  AnimeListItem right,
) {
  switch (sort) {
    case AnimeListSortOption.popularity:
      return 0;
    case AnimeListSortOption.score:
      return right.anime.score.compareTo(left.anime.score);
    case AnimeListSortOption.airedOn:
      return right.anime.airedOn.compareTo(left.anime.airedOn);
  }
}
