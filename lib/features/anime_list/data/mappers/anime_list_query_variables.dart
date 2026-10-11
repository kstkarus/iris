import 'package:iris/entities/user_rate/data/user_rate_dto.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/anime_list/domain/entities/anime_genre.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/entities/season_filter.dart';

/// The GraphQL variables of Shikimori's `animes` for [query]. A set is sent
/// in a fixed order and an empty one as null.
Map<String, dynamic> shikimoriAnimeListVariables(AnimeListQuery query) {
  final filters = query.filters;
  return {
    'page': query.page,
    'limit': query.limit,
    'search': query.search.isEmpty ? null : query.search,
    'order': query.sort.apiValue,
    'kind': _joinOrNull([
      for (final kind in _ordered(AnimeKindFilter.values, filters.kinds))
        kind.apiValue,
    ]),
    'status': _joinOrNull([
      for (final status in _ordered(AnimeStatusFilter.values, filters.statuses))
        status.apiValue,
    ]),
    'mylist': _myList(filters),
    'genre': _joinOrNull(_genreIds(filters.genres)),
    'season': _joinOrNull(
      [for (final season in filters.seasons) season.apiValue]..sort(),
    ),
    'rating': _joinOrNull([
      for (final rating in _ordered(AnimeRatingFilter.values, filters.ratings))
        rating.apiValue,
    ]),
    'duration': _joinOrNull([
      for (final duration in _ordered(
        AnimeDurationFilter.values,
        filters.durations,
      ))
        duration.apiValue,
    ]),
  };
}

extension AnimeListSortOptionApi on AnimeListSortOption {
  String get apiValue => switch (this) {
    AnimeListSortOption.popularity => 'popularity',
    AnimeListSortOption.score => 'ranked',
    AnimeListSortOption.airedOn => 'aired_on',
  };
}

extension AnimeKindFilterApi on AnimeKindFilter {
  String get apiValue => name;
}

extension AnimeStatusFilterApi on AnimeStatusFilter {
  String get apiValue => switch (this) {
    AnimeStatusFilter.released => 'released',
    AnimeStatusFilter.ongoing => 'ongoing',
    AnimeStatusFilter.announced => 'anons',
  };
}

extension AnimeRatingFilterApi on AnimeRatingFilter {
  String get apiValue => switch (this) {
    AnimeRatingFilter.g => 'g',
    AnimeRatingFilter.pg => 'pg',
    AnimeRatingFilter.pg13 => 'pg_13',
    AnimeRatingFilter.r => 'r',
    AnimeRatingFilter.rPlus => 'r_plus',
  };
}

extension AnimeDurationFilterApi on AnimeDurationFilter {
  String get apiValue => switch (this) {
    AnimeDurationFilter.short => 'S',
    AnimeDurationFilter.standard => 'D',
    AnimeDurationFilter.long => 'F',
  };
}

extension SeasonFilterApi on SeasonFilter {
  /// Shikimori's `season` value: `fall_2026`, `2025`, `2010_2019`,
  /// `1900_1999`.
  String get apiValue => switch (kind) {
    SeasonFilterKind.season => '${season!.name}_$year',
    SeasonFilterKind.year => '$year',
    SeasonFilterKind.decade => '${year}_${year + 9}',
    SeasonFilterKind.before2000 => '1900_1999',
  };
}

/// Shikimori's `mylist` value: the statuses wanted, and `!completed` to
/// leave out what is finished.
String? _myList(AnimeListFilters filters) => _joinOrNull([
  for (final status in _ordered(UserRateStatus.values, filters.myList))
    UserRateDto.statusToApi(status),
  if (filters.hideCompleted) '!completed',
]);

String? _joinOrNull(List<String> values) =>
    values.isEmpty ? null : values.join(',');

List<T> _ordered<T>(List<T> order, Set<T> values) =>
    order.where(values.contains).toList(growable: false);

List<String> _genreIds(Set<AnimeGenre> genres) =>
    [for (final genre in genres) genre.id]
      ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
