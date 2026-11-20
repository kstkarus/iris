import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/anime_details/data/datasources/remote_anime_details_data_source.dart';
import 'package:iris/features/anime_details/data/repositories/remote_anime_details_repository.dart';
import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/shared/models/details_description.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

import '../../../../helpers/fake_http_adapter.dart';

void main() {
  test('keeps character link targets in remote anime details', () async {
    final repository = RemoteAnimeDetailsRepository(
      dataSource: RemoteAnimeDetailsDataSource(
        client: ShikimoriGraphQlClient(
          dio: fakeDio(
            (request) => FakeReply(200, {
              'data': {
                'animes': [
                  {
                    'id': '5114',
                    'name': 'Fullmetal Alchemist: Brotherhood',
                    'russian': 'Fullmetal Alchemist: Brotherhood RU',
                    'description':
                        'A remake of [anime=121]Fullmetal Alchemist[/anime].\n\n'
                        'Follow [character=12 alphonse-elric].',
                    if (((request.data as Map)['query'] as String).contains(
                      'descriptionHtml',
                    ))
                      'descriptionHtml':
                          '<div class="b-text_with_paragraphs">A remake of '
                          '<a href="/animes/121">Fullmetal Alchemist</a>.<br><br>'
                          'Alphonse Elric is also in the cast. Follow '
                          '<a href="https://shikimori.io/characters/z12-alphonse-elric">Alphonse  Elric</a>'
                          ' and <a href="https://other.example/characters/9">Edward</a>.</div>',
                    'kind': 'tv',
                    'score': 9.1,
                    'status': 'released',
                    'episodes': 64,
                    'episodesAired': 0,
                    'airedOn': {'date': '2009-04-05'},
                    'poster': {
                      'originalUrl':
                          'https://shikimori.one/posters/5114/original.jpg',
                    },
                  },
                ],
              },
            }),
          ),
        ),
      ),
    );

    final details = await repository.fetchAnimeDetails('5114');

    expect(
      details,
      const AnimeDetails(
        anime: AnimeSummary(
          id: '5114',
          name: 'Fullmetal Alchemist: Brotherhood',
          russian: 'Fullmetal Alchemist: Brotherhood RU',
          kind: 'tv',
          score: 9.1,
          status: 'released',
          episodes: 64,
          episodesAired: 64,
          airedOn: '2009-04-05',
          posterUrl: 'https://shikimori.one/posters/5114/original.jpg',
        ),
        description: DetailsDescription(
          'A remake of Fullmetal Alchemist.\n\n'
          'Alphonse Elric is also in the cast. Follow Alphonse Elric and Edward.',
          characterLinks: [(start: 77, end: 91, characterId: '12')],
        ),
      ),
    );
  });

  test('throws not found when remote details response is empty', () async {
    final repository = RemoteAnimeDetailsRepository(
      dataSource: RemoteAnimeDetailsDataSource(
        client: ShikimoriGraphQlClient(
          dio: fakeDio(
            (_) => FakeReply(200, {
              'data': {'animes': []},
            }),
          ),
        ),
      ),
    );

    expect(
      () => repository.fetchAnimeDetails('missing'),
      throwsA(isA<ResourceNotFoundException>()),
    );
  });

  test('rethrows typed network exceptions from remote details', () async {
    final repository = RemoteAnimeDetailsRepository(
      dataSource: RemoteAnimeDetailsDataSource(
        client: ShikimoriGraphQlClient(
          dio: fakeDio(
            (_) => throw DioException(
              requestOptions: RequestOptions(path: '/api/graphql'),
              type: DioExceptionType.receiveTimeout,
            ),
          ),
        ),
      ),
    );

    expect(
      () => repository.fetchAnimeDetails('5114'),
      throwsA(isA<NetworkRequestException>()),
    );
  });
}
