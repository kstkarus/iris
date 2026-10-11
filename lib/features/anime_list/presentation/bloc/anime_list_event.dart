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

class AnimeListCriteriaApplied extends AnimeListEvent {
  const AnimeListCriteriaApplied({this.sort, this.filters});

  final AnimeListSortOption? sort;
  final AnimeListFilters? filters;
}

/// The Shikimori session began or ended: entries in the user's list come
/// with the titles only while signed in. [reload] is false for the state
/// the catalog starts in.
class AnimeListAccountChanged extends AnimeListEvent {
  const AnimeListAccountChanged({required this.signedIn, this.reload = true});

  final bool signedIn;
  final bool reload;
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
