import 'package:iris/features/anime_details/domain/entities/anime_details.dart';

abstract interface class AnimeDetailsRepository {
  Future<AnimeDetails> fetchAnimeDetails(String id);
}
