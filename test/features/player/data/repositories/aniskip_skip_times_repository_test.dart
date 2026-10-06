import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/data/repositories/aniskip_skip_times_repository.dart';
import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/shared/network/aniskip_api_client.dart';
import 'package:iris/shared/network/aniskip_dio_factory.dart';

void main() {
  late List<RequestOptions> requests;

  AniSkipSkipTimesRepository repositoryAnswering(
    int statusCode,
    Map<String, dynamic> body,
  ) {
    requests = [];
    final dio = createAniSkipDio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: statusCode,
              data: body,
            ),
            true,
          );
        },
      ),
    );
    return AniSkipSkipTimesRepository(client: AniSkipApiClient(dio: dio));
  }

  test('asks for the episode with its length and maps the times', () async {
    final repository = repositoryAnswering(200, {
      'found': true,
      'results': [
        {
          'interval': {'startTime': 153.346, 'endTime': 243.346},
          'skipType': 'op',
        },
        {
          'interval': {'startTime': 1370, 'endTime': 1460},
          'skipType': 'mixed-ed',
        },
        {
          'interval': {'startTime': 10, 'endTime': 20},
          'skipType': 'something-new',
        },
      ],
    });

    final segments = await repository.find(
      animeId: '52991',
      episode: 5,
      duration: const Duration(milliseconds: 1469968),
    );

    expect(requests.single.path, '/v2/skip-times/52991/5');
    expect(requests.single.queryParameters, {
      'types': ['op', 'ed', 'mixed-op', 'mixed-ed', 'recap'],
      'episodeLength': '1469.968',
    });
    expect(segments, const [
      PlayerSkipSegment(
        kind: PlayerSkipKind.opening,
        start: Duration(milliseconds: 153346),
        end: Duration(milliseconds: 243346),
      ),
      PlayerSkipSegment(
        kind: PlayerSkipKind.ending,
        start: Duration(seconds: 1370),
        end: Duration(seconds: 1460),
      ),
    ]);
  });

  test('knows nothing when AniSkip has no times for the episode', () async {
    final repository = repositoryAnswering(404, {
      'found': false,
      'results': <Object>[],
      'statusCode': 404,
    });

    final segments = await repository.find(
      animeId: '52991',
      episode: 40,
      duration: const Duration(minutes: 24),
    );

    expect(segments, isEmpty);
  });

  test('does not ask without a MyAnimeList id', () async {
    final repository = repositoryAnswering(200, {'found': true});

    final segments = await repository.find(
      animeId: 'saved-magnet',
      episode: 1,
      duration: const Duration(minutes: 24),
    );

    expect(segments, isEmpty);
    expect(requests, isEmpty);
  });

  test('swallows malformed answers', () async {
    final repository = repositoryAnswering(200, {
      'found': true,
      'results': [
        {'skipType': 'op'},
      ],
    });

    final segments = await repository.find(
      animeId: '52991',
      episode: 5,
      duration: const Duration(minutes: 24),
    );

    expect(segments, isEmpty);
  });
}
