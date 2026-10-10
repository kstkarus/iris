import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/data/remote_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;
  late FakeReply Function(RequestOptions) server;

  RemoteUserRateRepository repository() {
    adapter = FakeHttpAdapter((options) => server(options));
    final dio = Dio(BaseOptions(baseUrl: 'https://shikimori.io'))
      ..httpClientAdapter = adapter;
    return RemoteUserRateRepository(
      graphQl: ShikimoriGraphQlClient(dio: dio),
      dio: dio,
    );
  }

  Map<String, dynamic> body(RequestOptions options) =>
      jsonDecode(jsonEncode(options.data)) as Map<String, dynamic>;

  test('reads the entry from the anime', () async {
    server = (_) => const FakeReply(200, {
      'data': {
        'animes': [
          {
            'id': '1',
            'userRate': {'id': '77', 'status': 'on_hold', 'episodes': 5},
          },
        ],
      },
    });

    final rate = await repository().fetch('1');

    expect(
      rate,
      const UserRate(id: '77', status: UserRateStatus.onHold, episodes: 5),
    );
    expect(body(adapter.requests.single)['variables'], {'id': '1'});
  });

  test('an anime not in the list has no entry', () async {
    server = (_) => const FakeReply(200, {
      'data': {
        'animes': [
          {'id': '1', 'userRate': null},
        ],
      },
    });

    expect(await repository().fetch('1'), isNull);
  });

  test('adds an anime with the account and the anime', () async {
    server = (_) => const FakeReply(201, {
      'id': 16,
      'user_id': 42,
      'target_id': 1,
      'target_type': 'Anime',
      'status': 'watching',
      'episodes': 1,
    });

    final rate = await repository().save(
      userId: '42',
      animeId: '1',
      rateId: null,
      status: UserRateStatus.watching,
      episodes: 1,
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/v2/user_rates');
    expect(body(request), {
      'user_rate': {
        'user_id': '42',
        'target_id': '1',
        'target_type': 'Anime',
        'status': 'watching',
        'episodes': 1,
      },
    });
    expect(rate.id, '16');
  });

  test('changes an entry in place', () async {
    server = (_) =>
        const FakeReply(200, {'id': 16, 'status': 'completed', 'episodes': 12});

    final rate = await repository().save(
      userId: '42',
      animeId: '1',
      rateId: '16',
      status: UserRateStatus.onHold,
      episodes: 12,
    );

    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/api/v2/user_rates/16');
    expect(body(request), {
      'user_rate': {'status': 'on_hold', 'episodes': 12},
    });
    // Shikimori finishes an anime whose last episode is marked.
    expect(rate.status, UserRateStatus.completed);
  });

  test('removes an entry', () async {
    server = (_) => const FakeReply(204);

    await repository().remove('16');

    final request = adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/api/v2/user_rates/16');
  });

  test('a refused change is a response error', () async {
    server = (_) => const FakeReply(422, {'errors': []});

    await expectLater(
      repository().save(
        userId: '42',
        animeId: '1',
        rateId: '16',
        status: UserRateStatus.watching,
        episodes: 1,
      ),
      throwsA(isA<RemoteResponseException>()),
    );
  });
}
