import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/profile/data/repositories/remote_user_list_repository.dart';
import 'package:iris/features/profile/domain/repositories/user_list_repository.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

import '../../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;
  late FakeReply reply;

  RemoteUserListRepository repository() {
    adapter = FakeHttpAdapter((_) => reply);
    return RemoteUserListRepository(
      client: ShikimoriGraphQlClient(
        dio: Dio(BaseOptions(baseUrl: 'https://shikimori.io'))
          ..httpClientAdapter = adapter,
      ),
    );
  }

  Map<String, dynamic> entry(String id, {Object? anime}) => {
    'id': 'r$id',
    'status': 'watching',
    'episodes': 5,
    'score': 8,
    'anime':
        anime ??
        {
          'id': id,
          'name': 'Dandadan',
          'russian': 'Дандадан',
          'kind': 'tv',
          'score': 8.38,
          'status': 'ongoing',
          'episodes': 12,
          'episodesAired': 6,
          'nextEpisodeAt': '2026-10-12T15:00:00+03:00',
          'airedOn': {'year': 2026, 'month': 7, 'day': 0, 'date': '2026-07-01'},
          'poster': {'mainUrl': 'https://shikimori.io/main.webp'},
        },
  };

  test('reads one status, the most recently changed first', () async {
    reply = FakeReply(200, {
      'data': {
        'userRates': [
          entry('1'),
          // An anime Shikimori no longer has is left out.
          entry('2', anime: null)..['anime'] = null,
        ],
      },
    });

    final page = await repository().page(
      userId: '42',
      status: UserRateStatus.onHold,
      page: 2,
    );

    final listed = page.entries.single;
    expect(
      listed.rate,
      const UserRate(
        id: 'r1',
        status: UserRateStatus.watching,
        episodes: 5,
        score: 8,
      ),
    );
    expect(listed.anime.russian, 'Дандадан');
    expect(listed.anime.airedOn, '2026-07');
    expect(listed.anime.posterUrl, 'https://shikimori.io/main.webp');
    expect(listed.anime.nextEpisodeAt, DateTime.utc(2026, 10, 12, 12));
    expect(page.hasMore, isFalse);

    final body =
        jsonDecode(jsonEncode(adapter.requests.single.data))
            as Map<String, dynamic>;
    expect(body['variables'], {
      'userId': '42',
      'status': 'on_hold',
      'page': 2,
      'limit': UserListRepository.pageSize,
    });
  });

  test('a full page may have more after it', () async {
    reply = FakeReply(200, {
      'data': {
        'userRates': [
          for (var i = 0; i < UserListRepository.pageSize; i++) entry('$i'),
        ],
      },
    });

    final page = await repository().page(
      userId: '42',
      status: UserRateStatus.watching,
      page: 1,
    );

    expect(page.hasMore, isTrue);
  });

  test('a response without the list is an error', () async {
    reply = const FakeReply(200, {
      'data': {'userRates': null},
    });

    await expectLater(
      repository().page(userId: '42', status: UserRateStatus.watching, page: 1),
      throwsA(isA<RemoteResponseException>()),
    );
  });
}
