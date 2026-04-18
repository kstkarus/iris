import 'package:iris/features/anime_list/domain/entities/anime_list_page_result.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';

abstract class AnimeListEvent {
  const AnimeListEvent();
}

class AnimeListStarted extends AnimeListEvent {
  const AnimeListStarted();
}

class AnimeListInitialRetryRequested extends AnimeListEvent {
  const AnimeListInitialRetryRequested();
}

class AnimeListNextPageRequested extends AnimeListEvent {
  const AnimeListNextPageRequested();
}

class AnimeListSearchChanged extends AnimeListEvent {
  const AnimeListSearchChanged(this.query);

  final String query;
}

class AnimeListSearchCleared extends AnimeListEvent {
  const AnimeListSearchCleared();
}

class AnimeListSortChanged extends AnimeListEvent {
  const AnimeListSortChanged(this.sort);

  final AnimeListSortOption sort;
}

class AnimeListCriteriaApplied extends AnimeListEvent {
  const AnimeListCriteriaApplied({this.sort, this.filters});

  final AnimeListSortOption? sort;
  final AnimeListFilters? filters;
}

class AnimeListCriteriaReset extends AnimeListEvent {
  const AnimeListCriteriaReset();
}

class AnimeListPageLoaded extends AnimeListEvent {
  const AnimeListPageLoaded({
    required this.sessionId,
    required this.result,
    required this.query,
    required this.append,
  });

  final int sessionId;
  final AnimeListPageResult result;
  final AnimeListQuery query;
  final bool append;
}

class AnimeListPageFailed extends AnimeListEvent {
  const AnimeListPageFailed({
    required this.sessionId,
    required this.query,
    required this.append,
  });

  final int sessionId;
  final AnimeListQuery query;
  final bool append;
}
