import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/data/remote_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';
import 'package:iris/shared/network/shikimori_rest_client.dart';
import 'package:iris/shared/storage/shikimori_session_store.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_secure_storage.dart';

void main() {
  late FakeHttpAdapter adapter;
  late FutureOr<FakeReply> Function(RequestOptions) server;
  late ShikimoriSessionStore session;

  RemoteUserRateRepository repository() {
    adapter = FakeHttpAdapter((options) => server(options));
    session = ShikimoriSessionStore(FakeSecureStorage());
    final dio = Dio(BaseOptions(baseUrl: 'https://shikimori.io'))
      ..httpClientAdapter = adapter;
    return RemoteUserRateRepository(
      graphQl: ShikimoriGraphQlClient(dio: dio),
      rest: ShikimoriRestClient(dio: dio),
      session: session,
    );
  }

  ShikimoriTokens tokens(String name) => ShikimoriTokens(
    accessToken: 'access-$name',
    refreshToken: 'refresh-$name',
    expiresAt: DateTime.utc(2026, 10, 15),
  );

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

  test('reads the episode count of the anime with the entry', () async {
    server = (_) => const FakeReply(200, {
      'data': {
        'animes': [
          {'id': '1', 'episodes': 12, 'userRate': null},
        ],
      },
    });

    final entry = await repository().fetchWithTotal('1');

    expect(entry.rate, isNull);
    expect(entry.totalEpisodes, 12);
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
      score: 0,
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
        'score': 0,
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
      score: 8,
    );

    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/api/v2/user_rates/16');
    expect(body(request), {
      'user_rate': {'status': 'on_hold', 'episodes': 12, 'score': 8},
    });
    // Shikimori finishes an anime whose last episode is marked.
    expect(rate.status, UserRateStatus.completed);
  });

  test('removes an entry', () async {
    server = (_) => const FakeReply(204);

    await repository().remove(animeId: '1', rateId: '16');

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
        score: 0,
      ),
      throwsA(isA<RemoteResponseException>()),
    );
  });

  test(
    'an old save returns its result without publishing after sign-in',
    () async {
      final response = Completer<FakeReply>();
      server = (_) => response.future;
      final repo = repository();
      await session.write(tokens('a'));
      final changes = <UserRateChange>[];
      final subscription = repo.changes.listen(changes.add);

      final saving = repo.save(
        userId: '42',
        animeId: '1',
        rateId: null,
        status: UserRateStatus.watching,
        episodes: 1,
        score: 0,
      );
      await pumpEventQueue();
      await session.write(tokens('b'));
      // A re-login as A is a new session too; the old request still cannot
      // publish into it.
      await session.write(tokens('a-again'));
      response.complete(
        const FakeReply(201, {'id': 16, 'status': 'watching', 'episodes': 1}),
      );

      expect((await saving).id, '16');
      await pumpEventQueue();
      expect(changes, isEmpty);
      await subscription.cancel();
    },
  );

  test(
    'a same-session token renewal does not suppress a save change',
    () async {
      final response = Completer<FakeReply>();
      server = (_) => response.future;
      final repo = repository();
      await session.write(tokens('a'));
      final changes = <UserRateChange>[];
      final subscription = repo.changes.listen(changes.add);

      final saving = repo.save(
        userId: '42',
        animeId: '1',
        rateId: null,
        status: UserRateStatus.watching,
        episodes: 1,
        score: 0,
      );
      await pumpEventQueue();
      await session.renew(tokens('a-renewed'));
      response.complete(
        const FakeReply(201, {'id': 16, 'status': 'watching', 'episodes': 1}),
      );

      expect((await saving).id, '16');
      await pumpEventQueue();
      expect(changes, hasLength(1));
      expect(changes.single.animeId, '1');
      await subscription.cancel();
    },
  );

  test(
    'an old fetch returns its result without publishing after sign-in',
    () async {
      final response = Completer<FakeReply>();
      server = (_) => response.future;
      final repo = repository();
      await session.write(tokens('a'));
      final changes = <UserRateChange>[];
      final subscription = repo.changes.listen(changes.add);

      final fetching = repo.fetchWithTotal('1');
      await pumpEventQueue();
      await session.write(tokens('b'));
      response.complete(
        const FakeReply(200, {
          'data': {
            'animes': [
              {
                'id': '1',
                'episodes': 12,
                'userRate': {'id': '77', 'status': 'watching', 'episodes': 2},
              },
            ],
          },
        }),
      );

      expect((await fetching).rate?.id, '77');
      await pumpEventQueue();
      expect(changes, isEmpty);
      await subscription.cancel();
    },
  );

  test('an old removal does not publish after sign-in', () async {
    final response = Completer<FakeReply>();
    server = (_) => response.future;
    final repo = repository();
    await session.write(tokens('a'));
    final changes = <UserRateChange>[];
    final subscription = repo.changes.listen(changes.add);

    final removing = repo.remove(animeId: '1', rateId: '16');
    await pumpEventQueue();
    await session.write(tokens('b'));
    response.complete(const FakeReply(204));

    await removing;
    await pumpEventQueue();
    expect(changes, isEmpty);
    await subscription.cancel();
  });
}
