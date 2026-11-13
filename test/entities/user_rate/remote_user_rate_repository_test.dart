import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/data/remote_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_auth_interceptor.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';
import 'package:iris/shared/network/shikimori_oauth_client.dart';
import 'package:iris/shared/network/shikimori_oauth_config.dart';
import 'package:iris/shared/network/shikimori_rest_client.dart';
import 'package:iris/shared/storage/shikimori_session_store.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_secure_storage.dart';

void main() {
  late FakeHttpAdapter adapter;
  late FutureOr<FakeReply> Function(RequestOptions) server;
  late ShikimoriSessionStore session;

  RemoteUserRateRepository repository({bool authenticated = false}) {
    adapter = FakeHttpAdapter((options) => server(options));
    session = ShikimoriSessionStore(FakeSecureStorage());
    final dio = Dio(BaseOptions(baseUrl: 'https://shikimori.io'))
      ..httpClientAdapter = adapter;
    if (authenticated) {
      dio.interceptors.add(
        ShikimoriAuthInterceptor(
          dio: dio,
          store: session,
          oauth: ShikimoriOAuthClient(
            dio: Dio(),
            config: const ShikimoriOAuthConfig(clientId: '', clientSecret: ''),
          ),
          now: () => DateTime.utc(2026, 10, 10),
        ),
      );
    }
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

  test('episode-only updates omit score and unchanged status', () async {
    server = (_) => const FakeReply(200, {
      'id': 16,
      'status': 'rewatching',
      'episodes': 4,
      'score': 9,
      'rewatches': 2,
    });
    final saved = await repository().save(
      userId: '42',
      animeId: '1',
      rateId: '16',
      episodes: 4,
    );
    expect(body(adapter.requests.single), {
      'user_rate': {'episodes': 4},
    });
    expect(saved.score, 9);
    expect(saved.rewatches, 2);
  });

  test('score-only updates omit progress and status', () async {
    server = (_) => const FakeReply(200, {
      'id': 16,
      'status': 'watching',
      'episodes': 5,
      'score': 8,
    });

    final saved = await repository().save(
      userId: '42',
      animeId: '1',
      rateId: '16',
      score: 8,
    );

    expect(body(adapter.requests.single), {
      'user_rate': {'score': 8},
    });
    expect(saved.episodes, 5);
  });

  test('status-only updates omit progress and score', () async {
    server = (_) => const FakeReply(200, {
      'id': 16,
      'status': 'on_hold',
      'episodes': 5,
      'score': 8,
    });

    final saved = await repository().save(
      userId: '42',
      animeId: '1',
      rateId: '16',
      status: UserRateStatus.onHold,
    );

    expect(body(adapter.requests.single), {
      'user_rate': {'status': 'on_hold'},
    });
    expect(saved.episodes, 5);
    expect(saved.score, 8);
  });

  test('queries viewing cycle metadata for reset detection', () async {
    server = (_) => const FakeReply(200, {
      'data': {
        'animes': [
          {
            'id': '1',
            'userRate': {
              'id': '16',
              'status': 'watching',
              'episodes': 2,
              'rewatches': 3,
            },
          },
        ],
      },
    });
    final saved = await repository().fetch('1');
    expect(saved?.rewatches, 3);
    expect(body(adapter.requests.single)['query'], contains('rewatches'));
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

  test('mutations from different owners settle in request order', () async {
    final firstResponse = Completer<FakeReply>();
    server = (request) {
      if (adapter.requests.length == 1) return firstResponse.future;
      if (request.method == 'DELETE') return const FakeReply(204);
      return const FakeReply(200, {
        'id': 16,
        'status': 'watching',
        'episodes': 5,
      });
    };
    final repo = repository();
    await session.write(tokens('a'));
    final changes = <UserRateChange>[];
    final subscription = repo.changes.listen(changes.add);

    final first = repo.save(
      userId: '42',
      animeId: '1',
      rateId: '16',
      episodes: 2,
    );
    final second = repo.save(
      userId: '42',
      animeId: '1',
      rateId: '16',
      episodes: 5,
    );
    final third = repo.remove(animeId: '1', rateId: '16');
    await pumpEventQueue();
    expect(adapter.requests.map((request) => request.method), ['PATCH']);

    firstResponse.complete(
      const FakeReply(200, {'id': 16, 'status': 'watching', 'episodes': 2}),
    );
    await Future.wait([first, second, third]);
    await pumpEventQueue();

    expect(adapter.requests.map((request) => request.method), [
      'PATCH',
      'PATCH',
      'DELETE',
    ]);
    expect(changes.map((change) => change.rate?.episodes), [2, 5, null]);
    await subscription.cancel();
  });

  test('a failed queued request does not block the next mutation', () async {
    final firstResponse = Completer<FakeReply>();
    server = (_) => adapter.requests.length == 1
        ? firstResponse.future
        : const FakeReply(200, {'id': 16, 'status': 'watching', 'episodes': 3});
    final repo = repository();

    final failed = expectLater(
      repo.save(userId: '42', animeId: '1', rateId: '16', episodes: 2),
      throwsA(isA<RemoteResponseException>()),
    );
    final next = repo.save(
      userId: '42',
      animeId: '1',
      rateId: '16',
      episodes: 3,
    );
    await pumpEventQueue();
    expect(adapter.requests, hasLength(1));
    firstResponse.complete(const FakeReply(422));

    await failed;
    expect((await next).episodes, 3);
    expect(adapter.requests, hasLength(2));
  });

  test('a delayed fetch publishes before the save queued after it', () async {
    final fetchResponse = Completer<FakeReply>();
    server = (request) => request.path.contains('graphql')
        ? fetchResponse.future
        : const FakeReply(200, {'id': 16, 'status': 'watching', 'episodes': 5});
    final repo = repository();
    await session.write(tokens('a'));
    final changes = <UserRateChange>[];
    final subscription = repo.changes.listen(changes.add);

    final fetching = repo.fetchWithTotal('1');
    final saving = repo.save(
      userId: '42',
      animeId: '1',
      rateId: '16',
      episodes: 5,
    );
    await pumpEventQueue();
    expect(adapter.requests, hasLength(1));
    fetchResponse.complete(
      const FakeReply(200, {
        'data': {
          'animes': [
            {
              'id': '1',
              'episodes': 12,
              'userRate': {'id': 16, 'status': 'watching', 'episodes': 2},
            },
          ],
        },
      }),
    );

    expect((await fetching).rate?.episodes, 2);
    expect((await saving).episodes, 5);
    await pumpEventQueue();
    expect(changes.map((change) => change.rate?.episodes), [2, 5]);
    await subscription.cancel();
  });

  test(
    'queued requests never use the next account after a session switch',
    () async {
      final firstResponse = Completer<FakeReply>();
      server = (_) => adapter.requests.length == 1
          ? firstResponse.future
          : const FakeReply(200, {
              'id': 17,
              'status': 'watching',
              'episodes': 4,
            });
      final repo = repository(authenticated: true);
      await session.write(tokens('a'));
      final changes = <UserRateChange>[];
      final subscription = repo.changes.listen(changes.add);

      final first = repo.save(
        userId: '42',
        animeId: '1',
        rateId: '16',
        episodes: 1,
      );
      final oldSave = expectLater(
        repo.save(userId: '42', animeId: '1', rateId: '16', episodes: 2),
        throwsA(isA<NetworkRequestException>()),
      );
      final oldFetch = expectLater(
        repo.fetch('1'),
        throwsA(isA<NetworkRequestException>()),
      );
      final oldRemove = expectLater(
        repo.remove(animeId: '1', rateId: '16'),
        throwsA(isA<NetworkRequestException>()),
      );
      await pumpEventQueue();
      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer access-a',
      );

      await session.write(tokens('b'));
      final current = repo.save(
        userId: '7',
        animeId: '1',
        rateId: '17',
        episodes: 4,
      );
      firstResponse.complete(
        const FakeReply(200, {'id': 16, 'status': 'watching', 'episodes': 1}),
      );

      await first;
      await oldSave;
      await oldFetch;
      await oldRemove;
      expect((await current).episodes, 4);
      await pumpEventQueue();
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.last.headers['Authorization'], 'Bearer access-b');
      expect(changes.map((change) => change.rate?.episodes), [4]);
      await subscription.cancel();
    },
  );

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
