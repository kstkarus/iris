import 'package:iris/features/anime_list/domain/entities/anime_list_page_result.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_list_repository.dart';

/// Answers every query with an empty last page, keeping the queries.
class RecordingAnimeListRepository implements AnimeListRepository {
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
