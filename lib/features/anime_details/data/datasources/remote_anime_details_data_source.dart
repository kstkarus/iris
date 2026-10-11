import 'package:iris/entities/anime/data/shikimori_anime_summary.dart';
import 'package:iris/features/anime_details/data/models/shikimori_anime_details_dto.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

class RemoteAnimeDetailsDataSource {
  const RemoteAnimeDetailsDataSource({required ShikimoriGraphQlClient client})
    : _client = client;

  final ShikimoriGraphQlClient _client;

  Future<ShikimoriAnimeDetailsDto> fetchAnimeDetails(String id) async {
    final items = await _client.queryList(
      'animes',
      document: _animeDetailsQuery,
      variables: {'id': id},
    );

    if (items.isEmpty) {
      throw ResourceNotFoundException('Anime details not found for id: $id');
    }

    final firstItem = items.first;
    final details = firstItem is Map<String, dynamic>
        ? ShikimoriAnimeDetailsDto.tryParse(firstItem)
        : null;
    if (details == null) {
      throw const RemoteResponseException(
        'Anime details response contains an invalid anime item.',
      );
    }

    return details;
  }
}

const _animeDetailsQuery =
    r'''
query AnimeDetails($id: String!) {
  animes(ids: $id, limit: 1, censored: true) {
'''
    '$shikimoriAnimeSummaryFields'
    r'''
    description
    poster {
      originalUrl
    }
    nextEpisodeAt
    rating
    studios {
      name
    }
    genres {
      name
      russian
      kind
    }
    fandubbers
    related {
      relationKind
      anime {
'''
    '$shikimoriAnimeSummaryFields'
    r'''
        poster {
          mainUrl
        }
      }
    }
  }
}
''';
