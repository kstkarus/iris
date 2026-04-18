import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

void main() {
  test('returns data when GraphQL response is successful', () async {
    final client = ShikimoriGraphQlClient(
      dio: _buildDioWithResponse(
        data: {
          'data': {
            'animes': [
              {'id': '1'},
            ],
          },
        },
      ),
    );

    final response = await client.query(document: '{ animes { id } }');

    expect(response, {
      'animes': [
        {'id': '1'},
      ],
    });
  });

  test(
    'throws remote response exception when GraphQL returns errors',
    () async {
      final client = ShikimoriGraphQlClient(
        dio: _buildDioWithResponse(
          data: {
            'errors': [
              {'message': 'GraphQL failure'},
            ],
          },
        ),
      );

      expect(
        () => client.query(document: '{ animes { id } }'),
        throwsA(
          isA<RemoteResponseException>().having(
            (exception) => exception.message,
            'message',
            'GraphQL failure',
          ),
        ),
      );
    },
  );

  test('throws network request exception when Dio throws a timeout', () async {
    final client = ShikimoriGraphQlClient(
      dio: _buildDioWithError(
        DioException(
          requestOptions: RequestOptions(path: '/api/graphql'),
          type: DioExceptionType.connectionTimeout,
        ),
      ),
    );

    expect(
      () => client.query(document: '{ animes { id } }'),
      throwsA(isA<NetworkRequestException>()),
    );
  });

  test(
    'throws remote response exception for an unexpected payload shape',
    () async {
      final client = ShikimoriGraphQlClient(
        dio: _buildDioWithResponse(data: 'unexpected'),
      );

      expect(
        () => client.query(document: '{ animes { id } }'),
        throwsA(isA<RemoteResponseException>()),
      );
    },
  );
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
