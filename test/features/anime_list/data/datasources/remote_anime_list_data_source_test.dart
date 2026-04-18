import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/anime_list/data/datasources/remote_anime_list_data_source.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

void main() {
  test(
    'uses GraphQL-specific scalar types for kind and status variables',
    () async {
      Map<String, dynamic>? requestPayload;
      final dio = Dio();

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestPayload = Map<String, dynamic>.from(options.data as Map);
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: {
                  'data': {'animes': []},
                },
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final dataSource = RemoteAnimeListDataSource(
        client: ShikimoriGraphQlClient(dio: dio),
      );

      await dataSource.fetchAnimePage(
        query: const AnimeListQuery(
          page: 1,
          limit: 12,
          filters: AnimeListFilters(
            kinds: {AnimeKindFilter.tv},
            statuses: {AnimeStatusFilter.released},
          ),
        ),
      );

      expect(
        requestPayload?['query'],
        allOf(
          contains(r'$kind: AnimeKindString'),
          contains(r'$status: AnimeStatusString'),
        ),
      );
    },
  );
}
