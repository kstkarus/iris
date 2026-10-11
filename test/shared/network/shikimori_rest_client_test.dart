import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_rest_client.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;

  ShikimoriRestClient client(FakeReply reply) {
    adapter = FakeHttpAdapter((_) => reply);
    return ShikimoriRestClient(
      dio: Dio(BaseOptions(baseUrl: 'https://shikimori.io'))
        ..httpClientAdapter = adapter,
    );
  }

  test('returns the decoded body', () async {
    final rest = client(
      const FakeReply(200, [
        {'id': 1},
      ]),
    );

    final data = await rest.get('/api/users/1/friends', query: {'limit': 100});

    expect(data, [
      {'id': 1},
    ]);
    expect(adapter.requests.single.queryParameters, {'limit': 100});
  });

  test('sends each method with its body', () async {
    final rest = client(const FakeReply(200));

    await rest.post('/a', data: {'x': 1});
    await rest.patch('/b', data: {'y': 2});
    await rest.delete('/c');

    expect(
      [for (final request in adapter.requests) request.method],
      ['POST', 'PATCH', 'DELETE'],
    );
    expect(adapter.requests[0].data, {'x': 1});
    expect(adapter.requests[1].data, {'y': 2});
  });

  test('maps a failed request onto the app exceptions', () async {
    final rest = client(const FakeReply(500));

    await expectLater(
      rest.get('/api/users/1/friends'),
      throwsA(isA<RemoteResponseException>()),
    );
  });
}
