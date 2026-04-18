import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/anime_details/data/datasources/remote_anime_details_data_source.dart';
import 'package:iris/features/anime_details/data/repositories/remote_anime_details_repository.dart';
import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

void main() {
  test('maps remote anime details and sanitizes description', () async {
    final repository = RemoteAnimeDetailsRepository(
      dataSource: RemoteAnimeDetailsDataSource(
        client: ShikimoriGraphQlClient(
          dio: _buildDioWithResponse(
            data: {
              'data': {
                'animes': [
                  {
                    'id': '5114',
                    'malId': '5114',
                    'name': 'Fullmetal Alchemist: Brotherhood',
                    'russian': 'Fullmetal Alchemist: Brotherhood RU',
                    'description':
                        'A remake of [anime=121]Fullmetal Alchemist[/anime].\n\n[character=1]Hero[/character]',
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
            },
          ),
        ),
      ),
    );

    final details = await repository.fetchAnimeDetails('5114');

    expect(
      details,
      const AnimeDetails(
        id: '5114',
        name: 'Fullmetal Alchemist: Brotherhood',
        russian: 'Fullmetal Alchemist: Brotherhood RU',
        description: 'A remake of Fullmetal Alchemist.\n\nHero',
        kind: 'tv',
        score: 9.1,
        status: 'released',
        episodes: 64,
        episodesAired: 64,
        airedOn: '2009-04-05',
        posterOriginalUrl: 'https://shikimori.one/posters/5114/original.jpg',
      ),
    );
  });

  test('throws not found when remote details response is empty', () async {
    final repository = RemoteAnimeDetailsRepository(
      dataSource: RemoteAnimeDetailsDataSource(
        client: ShikimoriGraphQlClient(
          dio: _buildDioWithResponse(
            data: {
              'data': {'animes': []},
            },
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
          dio: _buildDioWithError(
            DioException(
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

Dio _buildDioWithResponse({required Object? data}) {
  final dio = Dio();

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            data: data,
            statusCode: 200,
          ),
        );
      },
    ),
  );

  return dio;
}

Dio _buildDioWithError(DioException error) {
  final dio = Dio();

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(error);
      },
    ),
  );

  return dio;
}
