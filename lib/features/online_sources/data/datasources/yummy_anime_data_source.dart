import 'package:iris/features/online_sources/data/models/yummy_anime_dto.dart';
import 'package:iris/shared/network/yummy_anime_api_client.dart';

class YummyAnimeDataSource {
  const YummyAnimeDataSource({required YummyAnimeApiClient client})
    : _client = client;

  final YummyAnimeApiClient _client;

  Future<List<YummyAnimeDto>> search(String query) async {
    final items = await _client.searchAnime(query: query);
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) YummyAnimeDto.fromJson(item),
    ];
  }

  Future<List<YummyVideoDto>> videos(int animeId) async {
    final items = await _client.fetchVideos(animeId: animeId);
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) YummyVideoDto.fromJson(item),
    ];
  }
}
