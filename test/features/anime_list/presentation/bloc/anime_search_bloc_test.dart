import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/anime_list/domain/entities/anime_list_page_result.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_list_repository.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_search_bloc.dart';

void main() {
  test('fetches nothing without a query', () async {
    final repository = _RecordingRepository();
    final bloc = AnimeSearchBloc(repository: repository)
      ..add(const AnimeListSearchCleared())
      ..add(const AnimeListCriteriaApplied(sort: AnimeListSortOption.score));
    await Future<void>.delayed(Duration.zero);

    expect(repository.queries, isEmpty);
    expect(bloc.state.isInitialLoading, isFalse);
    expect(bloc.state.items, isEmpty);
    expect(bloc.state.sort, AnimeListSortOption.score);
    await bloc.close();
  });

  test('searches with the criteria it was given', () async {
    final repository = _RecordingRepository();
    final bloc = AnimeSearchBloc(repository: repository)
      ..add(const AnimeListCriteriaApplied(sort: AnimeListSortOption.score))
      ..add(const AnimeListSearchChanged('frieren'));
    await Future<void>.delayed(Duration.zero);

    expect(repository.queries.single.search, 'frieren');
    expect(repository.queries.single.sort, AnimeListSortOption.score);
    await bloc.close();
  });

  test('clearing the query drops the results and stops fetching', () async {
    final repository = _RecordingRepository();
    final bloc = AnimeSearchBloc(repository: repository)
      ..add(const AnimeListSearchChanged('frieren'));
    await Future<void>.delayed(Duration.zero);

    bloc.add(const AnimeListSearchCleared());
    await Future<void>.delayed(Duration.zero);

    expect(repository.queries, hasLength(1));
    expect(bloc.state.query, isEmpty);
    expect(bloc.state.items, isEmpty);
    await bloc.close();
  });
}

class _RecordingRepository implements AnimeListRepository {
  final queries = <AnimeListQuery>[];

  @override
  Future<AnimeListPageResult> fetchAnimePage({
    required AnimeListQuery query,
  }) async {
    queries.add(query);
    return AnimeListPageResult(
      items: const [],
      page: query.page,
      hasMore: false,
      query: query.search,
    );
  }
}
