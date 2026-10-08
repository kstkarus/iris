import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/data/models/shikimori_anime_dto.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

class RemoteAnimeListDataSource {
  const RemoteAnimeListDataSource({required ShikimoriGraphQlClient client})
    : _client = client;

  final ShikimoriGraphQlClient _client;

  Future<List<ShikimoriAnimeDto>> fetchAnimePage({
    required AnimeListQuery query,
  }) async {
    final response = await _client.query(
      document: _animePageQuery,
      variables: query.variables,
    );
    final items = response['animes'];

    if (items is! List) {
      throw const RemoteResponseException(
        'Anime page response does not contain a valid anime list.',
      );
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map(ShikimoriAnimeDto.fromJson)
        .toList(growable: false);
  }
}

const _animePageQuery = r'''
query AnimePage(
  $page: Int!,
  $limit: Int!,
  $search: String,
  $order: OrderEnum,
  $kind: AnimeKindString,
  $status: AnimeStatusString
) {
  animes(
    page: $page,
    limit: $limit,
    search: $search,
    order: $order,
    kind: $kind,
    status: $status,
    censored: true
  ) {
    id
    malId
    name
    russian
    english
    kind
    score
    status
    episodes
    episodesAired
    airedOn {
      year
      month
      day
      date
    }
    poster {
      mainUrl
      originalUrl
    }
  }
}
''';
