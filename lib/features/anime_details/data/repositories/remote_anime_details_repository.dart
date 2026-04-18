import 'package:iris/features/anime_details/data/datasources/remote_anime_details_data_source.dart';
import 'package:iris/features/anime_details/data/mappers/shikimori_anime_details_mapper.dart';
import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';

class RemoteAnimeDetailsRepository implements AnimeDetailsRepository {
  const RemoteAnimeDetailsRepository({required this.dataSource});

  final RemoteAnimeDetailsDataSource dataSource;

  @override
  Future<AnimeDetails> fetchAnimeDetails(String id) async {
    final details = await dataSource.fetchAnimeDetails(id);
    return mapShikimoriAnimeDetailsToDomain(details);
  }
}
