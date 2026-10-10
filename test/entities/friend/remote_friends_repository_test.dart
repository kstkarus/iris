import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/friend/data/remote_friends_repository.dart';
import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;
  late FakeReply Function(RequestOptions) server;

  RemoteFriendsRepository repository() {
    adapter = FakeHttpAdapter((options) => server(options));
    return RemoteFriendsRepository(
      dio: Dio(BaseOptions(baseUrl: 'https://shikimori.io'))
        ..httpClientAdapter = adapter,
    );
  }

  test('reads the friends once a session', () async {
    server = (_) => const FakeReply(200, [
      {
        'id': 942,
        'nickname': 'zero',
        'avatar': 'https://shikimori.io/x48/942.png',
        'image': {'x160': 'https://shikimori.io/x160/942.png'},
      },
      {'id': 7, 'nickname': 'seven'},
      {'nickname': 'no id'},
    ]);
    final friends = repository();

    final list = await friends.friends('1');
    await friends.friends('1');

    expect(list, const [
      Friend(
        id: '942',
        nickname: 'zero',
        avatarUrl: 'https://shikimori.io/x160/942.png',
      ),
      Friend(id: '7', nickname: 'seven', avatarUrl: ''),
    ]);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, '/api/users/1/friends');
    expect(adapter.requests.single.queryParameters, {'limit': 100});
  });

  test('reads the entry a friend keeps for the anime', () async {
    server = (options) => FakeReply(
      200,
      options.queryParameters['user_id'] == '7'
          ? [
              {
                'id': 5,
                'user_id': 7,
                'target_id': 1,
                'status': 'completed',
                'episodes': 12,
                'score': 9,
              },
            ]
          : const [],
    );
    final friends = repository();

    expect(
      await friends.rateOf(friendId: '7', animeId: '1'),
      const UserRate(
        id: '5',
        status: UserRateStatus.completed,
        episodes: 12,
        score: 9,
      ),
    );
    expect(await friends.rateOf(friendId: '8', animeId: '1'), isNull);
    await friends.rateOf(friendId: '7', animeId: '1');

    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.first.path, '/api/v2/user_rates');
    expect(adapter.requests.first.queryParameters, {
      'user_id': '7',
      'target_id': '1',
      'target_type': 'Anime',
    });
  });

  test('a failed request is asked again next time', () async {
    server = (_) => const FakeReply(503);
    final friends = repository();

    await expectLater(friends.friends('1'), throwsA(isA<Exception>()));
    await Future<void>.delayed(Duration.zero);
    server = (_) => const FakeReply(200, <Object>[]);

    expect(await friends.friends('1'), isEmpty);
    expect(adapter.requests, hasLength(2));
  });
}
