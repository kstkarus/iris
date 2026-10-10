import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/anime_list/domain/entities/anime_genre.dart';
import 'package:iris/features/anime_list/domain/entities/season_filter.dart';

enum AnimeListSortOption { popularity, score, airedOn }

enum AnimeKindFilter { tv, movie, ova, ona }

enum AnimeStatusFilter { released, ongoing, announced }

/// Age ratings offered; Shikimori's `rx` is never shown.
enum AnimeRatingFilter { g, pg, pg13, r, rPlus }

/// Episode length: under 10 minutes, under 30, and longer.
enum AnimeDurationFilter { short, standard, long }

class AnimeListFilters {
  const AnimeListFilters({
    this.kinds = const {},
    this.statuses = const {},
    this.myList = const {},
    this.hideCompleted = false,
    this.genres = const {},
    this.seasons = const {},
    this.ratings = const {},
    this.durations = const {},
  });

  final Set<AnimeKindFilter> kinds;
  final Set<AnimeStatusFilter> statuses;

  /// Titles in the signed-in user's list with these statuses.
  final Set<UserRateStatus> myList;

  /// Leaves out what the user has finished.
  final bool hideCompleted;

  /// Titles with all of these.
  final Set<AnimeGenre> genres;
  final Set<SeasonFilter> seasons;
  final Set<AnimeRatingFilter> ratings;
  final Set<AnimeDurationFilter> durations;

  bool get hasAny =>
      kinds.isNotEmpty ||
      statuses.isNotEmpty ||
      usesMyList ||
      genres.isNotEmpty ||
      seasons.isNotEmpty ||
      ratings.isNotEmpty ||
      durations.isNotEmpty;

  /// Whether the filters need a signed-in account.
  bool get usesMyList => myList.isNotEmpty || hideCompleted;

  AnimeListFilters copyWith({
    Set<AnimeKindFilter>? kinds,
    Set<AnimeStatusFilter>? statuses,
    Set<UserRateStatus>? myList,
    bool? hideCompleted,
    Set<AnimeGenre>? genres,
    Set<SeasonFilter>? seasons,
    Set<AnimeRatingFilter>? ratings,
    Set<AnimeDurationFilter>? durations,
  }) {
    return AnimeListFilters(
      kinds: kinds ?? this.kinds,
      statuses: statuses ?? this.statuses,
      myList: myList ?? this.myList,
      hideCompleted: hideCompleted ?? this.hideCompleted,
      genres: genres ?? this.genres,
      seasons: seasons ?? this.seasons,
      ratings: ratings ?? this.ratings,
      durations: durations ?? this.durations,
    );
  }

  /// The same filters without the user's list, for a signed-out catalog.
  AnimeListFilters withoutMyList() =>
      copyWith(myList: const {}, hideCompleted: false);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AnimeListFilters &&
        _sameSet(other.kinds, kinds) &&
        _sameSet(other.statuses, statuses) &&
        _sameSet(other.myList, myList) &&
        other.hideCompleted == hideCompleted &&
        _sameSet(other.genres, genres) &&
        _sameSet(other.seasons, seasons) &&
        _sameSet(other.ratings, ratings) &&
        _sameSet(other.durations, durations);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(_orderedKinds(kinds)),
    Object.hashAll(_orderedStatuses(statuses)),
    Object.hashAll(_ordered(UserRateStatus.values, myList)),
    hideCompleted,
    Object.hashAll(_genreIds(genres)),
    Object.hashAll(_seasonValues(seasons)),
    Object.hashAll(_ordered(AnimeRatingFilter.values, ratings)),
    Object.hashAll(_ordered(AnimeDurationFilter.values, durations)),
  );
}

class AnimeListQuery {
  const AnimeListQuery({
    required this.page,
    required this.limit,
    this.search = '',
    this.sort = AnimeListSortOption.popularity,
    this.filters = const AnimeListFilters(),
  });

  final int page;
  final int limit;
  final String search;
  final AnimeListSortOption sort;
  final AnimeListFilters filters;

  Map<String, dynamic> get variables {
    return {
      'page': page,
      'limit': limit,
      'search': search.isEmpty ? null : search,
      'order': sort.apiValue,
      'kind': _serializeKinds(filters.kinds),
      'status': _serializeStatuses(filters.statuses),
      'mylist': _serializeMyList(filters),
      'genre': _joinOrNull(_genreIds(filters.genres)),
      'season': _joinOrNull(_seasonValues(filters.seasons)),
      'rating': _joinOrNull([
        for (final rating in _ordered(
          AnimeRatingFilter.values,
          filters.ratings,
        ))
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

  AnimeListQuery copyWith({
    int? page,
    int? limit,
    String? search,
    AnimeListSortOption? sort,
    AnimeListFilters? filters,
  }) {
    return AnimeListQuery(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      search: search ?? this.search,
      sort: sort ?? this.sort,
      filters: filters ?? this.filters,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AnimeListQuery &&
        other.page == page &&
        other.limit == limit &&
        other.search == search &&
        other.sort == sort &&
        other.filters == filters;
  }

  @override
  int get hashCode => Object.hash(page, limit, search, sort, filters);
}

extension AnimeListSortOptionX on AnimeListSortOption {
  String get apiValue {
    switch (this) {
      case AnimeListSortOption.popularity:
        return 'popularity';
      case AnimeListSortOption.score:
        return 'ranked';
      case AnimeListSortOption.airedOn:
        return 'aired_on';
    }
  }
}

extension AnimeKindFilterX on AnimeKindFilter {
  String get apiValue {
    switch (this) {
      case AnimeKindFilter.tv:
        return 'tv';
      case AnimeKindFilter.movie:
        return 'movie';
      case AnimeKindFilter.ova:
        return 'ova';
      case AnimeKindFilter.ona:
        return 'ona';
    }
  }
}

extension AnimeStatusFilterX on AnimeStatusFilter {
  String get apiValue {
    switch (this) {
      case AnimeStatusFilter.released:
        return 'released';
      case AnimeStatusFilter.ongoing:
        return 'ongoing';
      case AnimeStatusFilter.announced:
        return 'anons';
    }
  }
}

extension AnimeRatingFilterX on AnimeRatingFilter {
  String get apiValue => switch (this) {
    AnimeRatingFilter.g => 'g',
    AnimeRatingFilter.pg => 'pg',
    AnimeRatingFilter.pg13 => 'pg_13',
    AnimeRatingFilter.r => 'r',
    AnimeRatingFilter.rPlus => 'r_plus',
  };
}

extension AnimeDurationFilterX on AnimeDurationFilter {
  String get apiValue => switch (this) {
    AnimeDurationFilter.short => 'S',
    AnimeDurationFilter.standard => 'D',
    AnimeDurationFilter.long => 'F',
  };
}

/// Shikimori's `mylist` value: the statuses wanted, and `!completed` to
/// leave out what is finished.
String? _serializeMyList(AnimeListFilters filters) => _joinOrNull([
  for (final status in _ordered(UserRateStatus.values, filters.myList))
    _userRateStatusApiValue(status),
  if (filters.hideCompleted) '!completed',
]);

String _userRateStatusApiValue(UserRateStatus status) => switch (status) {
  UserRateStatus.planned => 'planned',
  UserRateStatus.watching => 'watching',
  UserRateStatus.rewatching => 'rewatching',
  UserRateStatus.completed => 'completed',
  UserRateStatus.onHold => 'on_hold',
  UserRateStatus.dropped => 'dropped',
};

String? _joinOrNull(List<String> values) =>
    values.isEmpty ? null : values.join(',');

List<T> _ordered<T>(List<T> order, Set<T> values) =>
    order.where(values.contains).toList(growable: false);

List<String> _genreIds(Set<AnimeGenre> genres) =>
    [for (final genre in genres) genre.id]
      ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));

List<String> _seasonValues(Set<SeasonFilter> seasons) =>
    [for (final season in seasons) season.apiValue]..sort();

String? _serializeKinds(Set<AnimeKindFilter> kinds) {
  if (kinds.isEmpty) {
    return null;
  }

  return _orderedKinds(kinds).map((kind) => kind.apiValue).join(',');
}

String? _serializeStatuses(Set<AnimeStatusFilter> statuses) {
  if (statuses.isEmpty) {
    return null;
  }

  return _orderedStatuses(statuses).map((status) => status.apiValue).join(',');
}

bool _sameSet<T>(Set<T> first, Set<T> second) {
  if (first.length != second.length) {
    return false;
  }

  for (final item in first) {
    if (!second.contains(item)) {
      return false;
    }
  }

  return true;
}

List<AnimeKindFilter> _orderedKinds(Set<AnimeKindFilter> kinds) {
  return AnimeKindFilter.values.where(kinds.contains).toList(growable: false);
}

List<AnimeStatusFilter> _orderedStatuses(Set<AnimeStatusFilter> statuses) {
  return AnimeStatusFilter.values
      .where(statuses.contains)
      .toList(growable: false);
}
