import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';

enum AnimeListErrorType { none, initial, loadMore }

class AnimeListState {
  const AnimeListState({
    this.items = const [],
    this.page = 0,
    this.query = '',
    this.sort = AnimeListSortOption.popularity,
    this.filters = const AnimeListFilters(),
    this.hasMore = true,
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.hasLoadedOnce = false,
    this.errorType = AnimeListErrorType.none,
    this.signedIn = false,
  });

  final List<AnimeListItem> items;
  final int page;
  final String query;
  final AnimeListSortOption sort;
  final AnimeListFilters filters;
  final bool hasMore;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasLoadedOnce;
  final AnimeListErrorType errorType;

  /// A Shikimori account is signed in: the user's list can filter titles.
  final bool signedIn;

  AnimeListState copyWith({
    List<AnimeListItem>? items,
    int? page,
    String? query,
    AnimeListSortOption? sort,
    AnimeListFilters? filters,
    bool? hasMore,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasLoadedOnce,
    AnimeListErrorType? errorType,
    bool? signedIn,
  }) {
    return AnimeListState(
      items: items ?? this.items,
      page: page ?? this.page,
      query: query ?? this.query,
      sort: sort ?? this.sort,
      filters: filters ?? this.filters,
      hasMore: hasMore ?? this.hasMore,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
      errorType: errorType ?? this.errorType,
      signedIn: signedIn ?? this.signedIn,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AnimeListState &&
        _sameItems(other.items, items) &&
        other.page == page &&
        other.query == query &&
        other.sort == sort &&
        other.filters == filters &&
        other.hasMore == hasMore &&
        other.isInitialLoading == isInitialLoading &&
        other.isLoadingMore == isLoadingMore &&
        other.hasLoadedOnce == hasLoadedOnce &&
        other.errorType == errorType &&
        other.signedIn == signedIn;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(items),
    page,
    query,
    sort,
    filters,
    hasMore,
    isInitialLoading,
    isLoadingMore,
    hasLoadedOnce,
    errorType,
    signedIn,
  );
}

bool _sameItems(List<AnimeListItem> first, List<AnimeListItem> second) {
  if (first.length != second.length) {
    return false;
  }

  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }

  return true;
}
