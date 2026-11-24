import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/data/repositories/tenrai_episode_metadata_repository.dart';
import 'package:iris/features/player/domain/entities/episode_metadata.dart';
import 'package:iris/shared/network/tenrai_api_client.dart';
import 'package:iris/shared/network/tenrai_dio_factory.dart';

import '../../../../helpers/fake_http_adapter.dart';

void main() {
  TenraiEpisodeMetadataRepository repositoryWith(
    FakeReply Function(RequestOptions options) respond, {
    required List<RequestOptions> requests,
  }) {
    final adapter = FakeHttpAdapter((options) {
      requests.add(options);
      return respond(options);
    });
    final dio = createTenraiDio(wait: (_) async {})
      ..httpClientAdapter = adapter;
    return TenraiEpisodeMetadataRepository(client: TenraiApiClient(dio: dio));
  }

  test('maps episode titles, filler and recap flags from Tenrai', () async {
    final requests = <RequestOptions>[];
    final repository = repositoryWith(
      (_) => FakeReply(200, {
        'pagination': {'last_visible_page': 1, 'has_next_page': false},
        'data': [
          {
            'mal_id': 1,
            'title': 'Enter: Naruto Uzumaki!',
            'filler': false,
            'recap': false,
          },
          {
            'mal_id': 26,
            'title': 'Special Report: Live from the Forest of Death!',
            'filler': true,
            'recap': true,
          },
          {'mal_id': 27, 'title': '', 'filler': false, 'recap': false},
        ],
      }),
      requests: requests,
    );

    final episodes = await repository.findForAnime(animeId: '20');

    expect(requests.single.path, '/v1/anime/20/episodes');
    expect(requests.single.queryParameters, {'page': 1});
    expect(episodes, const {
      1: EpisodeMetadata(number: 1, title: 'Enter: Naruto Uzumaki!'),
      26: EpisodeMetadata(
        number: 26,
        title: 'Special Report: Live from the Forest of Death!',
        filler: true,
        recap: true,
      ),
    });

    // Cached for the session: second lookup makes no network request.
    final cached = await repository.findForAnime(animeId: '20');
    expect(cached, episodes);
    expect(requests, hasLength(1));
  });

  test(
    'fetches further pages only when needed and keeps earlier pages',
    () async {
      final requests = <RequestOptions>[];
      final repository = repositoryWith((options) {
        final page = options.queryParameters['page'] as int? ?? 1;
        if (page == 1) {
          return FakeReply(200, {
            'pagination': {'last_visible_page': 2, 'has_next_page': true},
            'data': [
              {'mal_id': 1, 'title': 'First', 'filler': false, 'recap': false},
              {
                'mal_id': 100,
                'title': 'Hundredth',
                'filler': true,
                'recap': false,
              },
            ],
          });
        }
        return FakeReply(200, {
          'pagination': {'last_visible_page': 2, 'has_next_page': false},
          'data': [
            {
              'mal_id': 101,
              'title': 'Gotta See! Gotta Know!',
              'filler': true,
              'recap': false,
            },
          ],
        });
      }, requests: requests);

      final firstPage = await repository.findForAnime(
        animeId: '20',
        upToEpisode: 24,
      );
      expect(firstPage.keys, [1, 100]);
      expect(requests, hasLength(1));

      final allPages = await repository.findForAnime(
        animeId: '20',
        upToEpisode: 101,
      );
      expect(allPages.keys, [1, 100, 101]);
      expect(allPages[101]?.filler, isTrue);
      expect(requests.map((r) => r.queryParameters['page']), [1, 2]);
    },
  );

  test('deduplicates concurrent lookups for the same anime', () async {
    final gate = Completer<void>();
    var calls = 0;
    final adapter = FakeHttpAdapter((_) async {
      calls++;
      await gate.future;
      return FakeReply(200, {
        'pagination': {'last_visible_page': 1, 'has_next_page': false},
        'data': [
          {'mal_id': 1, 'title': 'Pilot', 'filler': false, 'recap': false},
        ],
      });
    });
    final dio = createTenraiDio(wait: (_) async {})
      ..httpClientAdapter = adapter;
    final repository = TenraiEpisodeMetadataRepository(
      client: TenraiApiClient(dio: dio),
    );

    final first = repository.findForAnime(animeId: '52991');
    final second = repository.findForAnime(animeId: '52991');
    gate.complete();

    final results = await Future.wait([first, second]);
    expect(calls, 1);
    expect(results[0], results[1]);
  });

  test('caches 404 as empty for the session', () async {
    final requests = <RequestOptions>[];
    final repository = repositoryWith(
      (_) => const FakeReply(404, {'status': 404}),
      requests: requests,
    );

    expect(await repository.findForAnime(animeId: '999999'), isEmpty);
    expect(await repository.findForAnime(animeId: '999999'), isEmpty);
    expect(requests, hasLength(1));
  });

  test('skips requests without a valid positive MAL id', () async {
    final requests = <RequestOptions>[];
    final repository = repositoryWith(
      (_) => const FakeReply(200, {'data': <Object>[]}),
      requests: requests,
    );

    expect(await repository.findForAnime(animeId: ''), isEmpty);
    expect(await repository.findForAnime(animeId: 'saved-magnet'), isEmpty);
    expect(await repository.findForAnime(animeId: '-1'), isEmpty);
    expect(requests, isEmpty);
  });

  test('swallows errors and retries on a later lookup', () async {
    final requests = <RequestOptions>[];
    var fail = true;
    final repository = repositoryWith((_) {
      if (fail) return const FakeReply(500, {'error': 'boom'});
      return FakeReply(200, {
        'pagination': {'last_visible_page': 1, 'has_next_page': false},
        'data': [
          {'mal_id': 1, 'title': 'Recovered', 'filler': false, 'recap': false},
        ],
      });
    }, requests: requests);

    expect(await repository.findForAnime(animeId: '20'), isEmpty);
    fail = false;
    final recovered = await repository.findForAnime(animeId: '20');
    expect(recovered[1]?.title, 'Recovered');
    expect(requests, hasLength(2));
  });
}
