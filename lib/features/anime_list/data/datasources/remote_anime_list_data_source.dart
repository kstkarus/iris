import 'package:iris/entities/anime/data/shikimori_anime_summary.dart';
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

    return [for (final item in items) ?ShikimoriAnimeDto.tryParse(item)];
  }
}

const _animePageQuery =
    r'''
query AnimePage(
  $page: Int!,
  $limit: Int!,
  $search: String,
  $order: OrderEnum,
  $kind: AnimeKindString,
  $status: AnimeStatusString,
  $mylist: MylistString,
  $genre: String,
  $season: SeasonString,
  $rating: RatingString,
  $duration: DurationString
) {
  animes(
    page: $page,
    limit: $limit,
    search: $search,
    order: $order,
    kind: $kind,
    status: $status,
    mylist: $mylist,
    genre: $genre,
    season: $season,
    rating: $rating,
    duration: $duration,
    censored: true
  ) {
'''
    '$shikimoriAnimeSummaryFields'
    r'''
    poster {
      mainUrl
    }
    userRate {
      id
      status
      episodes
      score
    }
  }
}
''';
