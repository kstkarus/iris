import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/anime_list/domain/entities/anime_genre.dart';
import 'package:iris/features/anime_list/domain/entities/season_filter.dart';
import 'package:iris/shared/utils/equality.dart';

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

  /// The same filters without the user's list, for a signed-out catalog.
  AnimeListFilters withoutMyList() => AnimeListFilters(
    kinds: kinds,
    statuses: statuses,
    genres: genres,
    seasons: seasons,
    ratings: ratings,
    durations: durations,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AnimeListFilters &&
        sameSet(other.kinds, kinds) &&
        sameSet(other.statuses, statuses) &&
        sameSet(other.myList, myList) &&
        other.hideCompleted == hideCompleted &&
        sameSet(other.genres, genres) &&
        sameSet(other.seasons, seasons) &&
        sameSet(other.ratings, ratings) &&
        sameSet(other.durations, durations);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(kinds),
    Object.hashAllUnordered(statuses),
    Object.hashAllUnordered(myList),
    hideCompleted,
    Object.hashAllUnordered(genres),
    Object.hashAllUnordered(seasons),
    Object.hashAllUnordered(ratings),
    Object.hashAllUnordered(durations),
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
