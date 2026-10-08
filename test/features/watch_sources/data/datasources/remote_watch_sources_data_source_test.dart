import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/watch_sources/data/datasources/remote_watch_sources_data_source.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/nyaa_api_client.dart';

void main() {
  test('requests nyaa sources with q and maps the response items', () async {
    RequestOptions? capturedOptions;
    final dio = Dio();

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedOptions = options;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'count': 1,
                'data': [
                  {
                    'category': 'Anime - English-translated',
                    'title': '[Mock] Frieren Batch',
                    'link': 'https://nyaa.si/view/1',
                    'torrent': 'https://nyaa.si/download/1.torrent',
                    'magnet': 'magnet:?xt=urn:btih:test',
                    'size': '7.0 GiB',
                    'time': '2026-04-14 17:09',
                    'seeders': 33,
                    'leechers': 4,
                    'downloads': 269,
                  },
                ],
              },
            ),
          );
        },
      ),
    );

    final dataSource = RemoteWatchSourcesDataSource(
      client: NyaaApiClient(dio: dio),
    );

    final items = await dataSource.fetchSources(
      'Frieren: Beyond Journey\'s End',
    );

    expect(capturedOptions?.path, '/nyaa');
    expect(capturedOptions?.queryParameters, {
      'q': 'Frieren: Beyond Journey\'s End',
      'category': 'anime',
      'sort': 'seeders',
      'order': 'desc',
    });
    expect(items, hasLength(1));
    expect(items.first.title, '[Mock] Frieren Batch');
    expect(items.first.seeders, 33);
  });

  test(
    'returns an empty list when the service responds with no results',
    () async {
      final dio = Dio();

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {'count': 0, 'data': []},
              ),
            );
          },
        ),
      );

      final dataSource = RemoteWatchSourcesDataSource(
        client: NyaaApiClient(dio: dio),
      );

      final items = await dataSource.fetchSources('No Results');

      expect(items, isEmpty);
    },
  );

  test('converts network failures into app-level errors', () async {
    final dio = Dio();

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
            ),
          );
        },
      ),
    );

    final dataSource = RemoteWatchSourcesDataSource(
      client: NyaaApiClient(dio: dio),
    );

    expect(
      () => dataSource.fetchSources('Death Note'),
      throwsA(isA<NetworkRequestException>()),
    );
  });
}
