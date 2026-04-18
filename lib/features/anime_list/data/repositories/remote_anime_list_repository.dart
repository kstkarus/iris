import 'package:iris/features/anime_list/data/datasources/remote_anime_list_data_source.dart';
import 'package:iris/features/anime_list/data/mappers/shikimori_anime_mapper.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_page_result.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_list_repository.dart';

class RemoteAnimeListRepository implements AnimeListRepository {
  const RemoteAnimeListRepository({required this.dataSource});

  final RemoteAnimeListDataSource dataSource;

  @override
  Future<AnimeListPageResult> fetchAnimePage({
    required AnimeListQuery query,
  }) async {
    final anime = await dataSource.fetchAnimePage(query: query);
    final items = anime.map(mapShikimoriAnimeToDomain).toList(growable: false);

    return AnimeListPageResult(
      items: items,
      page: query.page,
      hasMore: items.length == query.limit,
      query: query.search,
    );
  }
}
