import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/anime_list/data/datasources/remote_anime_list_data_source.dart';
import 'package:iris/features/anime_list/data/repositories/remote_anime_list_repository.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_page_result.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

import '../../../../helpers/fake_http_adapter.dart';

void main() {
  test(
    'maps a successful remote anime page response to a page result',
    () async {
      final repository = RemoteAnimeListRepository(
        dataSource: RemoteAnimeListDataSource(
          client: ShikimoriGraphQlClient(
            dio: fakeDio(
              (_) => FakeReply(200, {
                'data': {
                  'animes': [
                    {
                      'id': '52299',
                      'name': 'Solo Leveling',
                      'russian': 'Solo Leveling RU',
                      'kind': 'tv',
                      'score': 8.34,
                      'status': 'released',
                      'episodes': 12,
                      'episodesAired': 12,
                      'airedOn': {'date': '2024-01-07'},
                      'poster': {
                        'mainUrl':
                            'https://shikimori.one/posters/52299/main.webp',
                      },
                    },
                  ],
                },
              }),
            ),
          ),
        ),
      );

      final result = await repository.fetchAnimePage(
        query: const AnimeListQuery(page: 1, limit: 12),
      );

      expect(
        result,
        const AnimeListPageResult(
          items: [
            AnimeListItem(
              anime: AnimeSummary(
                id: '52299',
                name: 'Solo Leveling',
                russian: 'Solo Leveling RU',
                kind: 'tv',
                score: 8.34,
                status: 'released',
                episodes: 12,
                episodesAired: 12,
                airedOn: '2024-01-07',
                posterUrl: 'https://shikimori.one/posters/52299/main.webp',
              ),
            ),
          ],
          page: 1,
          hasMore: false,
          query: '',
        ),
      );
    },
  );

  test('turns an empty remote anime page into hasMore false', () async {
    final repository = RemoteAnimeListRepository(
      dataSource: RemoteAnimeListDataSource(
        client: ShikimoriGraphQlClient(
          dio: fakeDio(
            (_) => FakeReply(200, {
              'data': {'animes': []},
            }),
          ),
        ),
      ),
    );

    final result = await repository.fetchAnimePage(
      query: const AnimeListQuery(page: 2, limit: 12),
    );

    expect(result.items, isEmpty);
    expect(result.hasMore, isFalse);
    expect(result.page, 2);
  });

  test('rethrows typed network exceptions from the remote source', () async {
    final repository = RemoteAnimeListRepository(
      dataSource: RemoteAnimeListDataSource(
        client: ShikimoriGraphQlClient(
          dio: fakeDio(
            (_) => throw DioException(
              requestOptions: RequestOptions(path: '/api/graphql'),
              type: DioExceptionType.connectionError,
            ),
          ),
        ),
      ),
    );

    expect(
      () => repository.fetchAnimePage(
        query: const AnimeListQuery(page: 1, limit: 12),
      ),
      throwsA(isA<NetworkRequestException>()),
    );
  });

  test('passes query criteria to the remote source request', () async {
    Map<String, dynamic>? requestPayload;
    final dio = fakeDio((options) {
      requestPayload = Map<String, dynamic>.from(options.data as Map);
      return FakeReply(200, {
        'data': {'animes': []},
      });
    });

    final repository = RemoteAnimeListRepository(
      dataSource: RemoteAnimeListDataSource(
        client: ShikimoriGraphQlClient(dio: dio),
      ),
    );

    await repository.fetchAnimePage(
      query: const AnimeListQuery(
        page: 3,
        limit: 12,
        search: 'fullmetal',
        sort: AnimeListSortOption.score,
        filters: AnimeListFilters(
          kinds: {AnimeKindFilter.movie, AnimeKindFilter.tv},
          statuses: {AnimeStatusFilter.released},
        ),
      ),
    );

    expect(requestPayload?['variables'], {
      'page': 3,
      'limit': 12,
      'search': 'fullmetal',
      'order': 'ranked',
      'kind': 'tv,movie',
      'status': 'released',
      'mylist': null,
      'genre': null,
      'season': null,
      'rating': null,
      'duration': null,
    });
  });
}
