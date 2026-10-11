import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  test('returns data when GraphQL response is successful', () async {
    final client = ShikimoriGraphQlClient(
      dio: fakeDio(
        (_) => FakeReply(200, {
          'data': {
            'animes': [
              {'id': '1'},
            ],
          },
        }),
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
        dio: fakeDio(
          (_) => FakeReply(200, {
            'errors': [
              {'message': 'GraphQL failure'},
            ],
          }),
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
      dio: fakeDio(
        (_) => throw DioException(
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

  test('queryList returns the list field and rejects anything else', () async {
    final client = ShikimoriGraphQlClient(
      dio: fakeDio(
        (_) => FakeReply(200, {
          'data': {
            'animes': [
              {'id': '1'},
            ],
            'genres': null,
          },
        }),
      ),
    );

    expect(await client.queryList('animes', document: '{ animes { id } }'), [
      {'id': '1'},
    ]);
    expect(
      () => client.queryList('genres', document: '{ genres { id } }'),
      throwsA(isA<RemoteResponseException>()),
    );
  });

  test(
    'throws remote response exception for an unexpected payload shape',
    () async {
      final client = ShikimoriGraphQlClient(
        dio: fakeDio((_) => FakeReply(200, 'unexpected')),
      );

      expect(
        () => client.query(document: '{ animes { id } }'),
        throwsA(isA<RemoteResponseException>()),
      );
    },
  );
}
