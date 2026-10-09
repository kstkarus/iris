import 'package:iris/features/online_sources/data/models/anilibria_episode_dto.dart';
import 'package:iris/features/online_sources/data/models/anilibria_release_dto.dart';
import 'package:iris/shared/network/anilibria_api_client.dart';
import 'package:iris/shared/network/network_exceptions.dart';

class AnilibriaDataSource {
  const AnilibriaDataSource({required AnilibriaApiClient client})
    : _client = client;

  final AnilibriaApiClient _client;

  Future<List<AnilibriaReleaseDto>> search(String query) async {
    final items = await _client.searchReleases(query: query);
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) AnilibriaReleaseDto.fromJson(item),
    ];
  }

  Future<AnilibriaReleaseDto> release(int releaseId) async {
    final release = AnilibriaReleaseDto.fromJson(
      await _client.fetchRelease(releaseId: releaseId),
    );
    if (release.id == 0) {
      throw const RemoteResponseException('AniLibria release has no id.');
    }
    return release;
  }

  Future<AnilibriaEpisodeDto> episode(String episodeId) async {
    return AnilibriaEpisodeDto.fromJson(
      await _client.fetchEpisode(episodeId: episodeId),
    );
  }
}
