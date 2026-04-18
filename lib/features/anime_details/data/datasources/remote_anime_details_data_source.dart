import 'package:iris/features/anime_details/data/models/shikimori_anime_details_dto.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

class RemoteAnimeDetailsDataSource {
  const RemoteAnimeDetailsDataSource({required ShikimoriGraphQlClient client})
    : _client = client;

  final ShikimoriGraphQlClient _client;

  Future<ShikimoriAnimeDetailsDto> fetchAnimeDetails(String id) async {
    final response = await _client.query(
      document: _animeDetailsQuery,
      variables: {'id': id},
    );
    final items = response['animes'];

    if (items is! List) {
      throw const RemoteResponseException(
        'Anime details response does not contain a valid anime list.',
      );
    }

    if (items.isEmpty) {
      throw ResourceNotFoundException('Anime details not found for id: $id');
    }

    final firstItem = items.first;
    if (firstItem is! Map<String, dynamic>) {
      throw const RemoteResponseException(
        'Anime details response contains an invalid anime item.',
      );
    }

    return ShikimoriAnimeDetailsDto.fromJson(firstItem);
  }
}

const _animeDetailsQuery = r'''
query AnimeDetails($id: String!) {
  animes(ids: $id, limit: 1, censored: true) {
    id
    malId
    name
    russian
    description
    kind
    score
    status
    episodes
    episodesAired
    airedOn {
      date
    }
    poster {
      originalUrl
    }
  }
}
''';
