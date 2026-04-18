import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_page_result.dart';

abstract interface class AnimeListRepository {
  Future<AnimeListPageResult> fetchAnimePage({required AnimeListQuery query});
}
