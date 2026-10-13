import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/online_sources/data/datasources/anilibria_data_source.dart';
import 'package:iris/features/online_sources/data/repositories/anilibria_online_sources_repository.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';
import 'package:iris/shared/network/anilibria_api_client.dart';
import 'package:iris/shared/network/network_exceptions.dart';

import '../../../../helpers/fake_http_adapter.dart';

/// Recorded from the live API (trimmed; CDN hosts replaced).
Object? _fixture(String name) =>
    jsonDecode(readFixture('anilibria/$name.json'));

const _frierenShikimoriId = '52991';

void main() {
  late List<RequestOptions> requests;

  /// Answers by path; a query in [failingQueries] fails like a dropped
  /// connection.
  AnilibriaOnlineSourcesRepository repository({
    Map<String, Object?>? searchResults,
    Set<String> failingQueries = const {},
    Object? release,
  }) {
    final dio = fakeDio((options) {
      requests.add(options);
      final path = options.path;
      final query = options.queryParameters['query'] as String?;
      if (query != null && failingQueries.contains(query)) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }
      final Object? data;
      if (path == '/app/search/releases') {
        data = searchResults?[query] ?? _fixture('search_frieren');
      } else if (path == '/anime/releases/9542') {
        data = release ?? _fixture('release_9542');
      } else if (path.startsWith('/anime/releases/episodes/')) {
        data = _fixture('episode_1');
      } else {
        return const FakeReply(404);
      }
      return FakeReply(200, data!);
    });
    return AnilibriaOnlineSourcesRepository(
      dataSource: AnilibriaDataSource(client: AnilibriaApiClient(dio: dio)),
    );
  }

  setUp(() => requests = []);

  test('keeps only the release that names the Shikimori id', () async {
    // The search also finds the second season, linked to another id.
    final releases = await repository().findReleases(
      shikimoriId: _frierenShikimoriId,
      titles: const ['Frieren'],
    );

    expect(requests.first.path, '/app/search/releases');
    expect(requests.first.queryParameters, {'query': 'Frieren'});
    expect(releases, hasLength(1));
    final release = releases.single;
    expect(release.provider, OnlineProvider.anilibria);
    expect(release.id, '9542');
    expect(release.dub, 'AniLibria');
    expect([for (final e in release.episodes) e.number], [1, 2, 3]);
    expect(release.episodes.first.title, '«Конец приключений»');
    expect(release.episodes.first.duration, const Duration(minutes: 26));
    expect(release.episodes.first.id, '9a416b99-4487-4d8a-960a-461089d36cad');
    expect(release.bestQuality, 1080);
  });

  test('fetches a release found earlier by its id', () async {
    final release = await repository().fetchRelease(
      provider: OnlineProvider.anilibria,
      id: '9542',
    );

    expect(requests.single.path, '/anime/releases/9542');
    expect(release.id, '9542');
    expect(release.episodes, hasLength(3));
  });

  test('a release AniLibria does not have is not found', () {
    expect(
      repository().fetchRelease(provider: OnlineProvider.anilibria, id: '1'),
      throwsA(isA<ResourceNotFoundException>()),
    );
    expect(
      repository().fetchRelease(provider: OnlineProvider.anilibria, id: 'x'),
      throwsA(isA<ResourceNotFoundException>()),
    );
  });

  test('leaves out episodes without streams', () async {
    final release = _fixture('release_9542')! as Map<String, dynamic>;
    final episodes = release['episodes'] as List;
    (episodes.first as Map)
      ..['hls_480'] = null
      ..['hls_720'] = null
      ..['hls_1080'] = null;

    final releases = await repository(
      release: release,
    ).findReleases(shikimoriId: _frierenShikimoriId, titles: const ['Frieren']);

    expect([for (final e in releases.single.episodes) e.number], [2, 3]);
  });

  test('a release with nothing to play is not offered', () async {
    final release = _fixture('release_9542')! as Map<String, dynamic>;
    for (final episode in release['episodes'] as List) {
      (episode as Map)
        ..['hls_480'] = null
        ..['hls_720'] = null
        ..['hls_1080'] = null;
    }

    final releases = await repository(
      release: release,
    ).findReleases(shikimoriId: _frierenShikimoriId, titles: const ['Frieren']);

    expect(releases, isEmpty);
  });

  test('searches each title once and fetches a match once', () async {
    await repository().findReleases(
      shikimoriId: _frierenShikimoriId,
      titles: const ['Frieren', ' Frieren ', 'Sousou no Frieren', ''],
    );

    final searches = requests.where(
      (request) => request.path == '/app/search/releases',
    );
    expect(
      [for (final s in searches) s.queryParameters['query']],
      ['Frieren', 'Sousou no Frieren'],
    );
    expect(
      requests.where((request) => request.path == '/anime/releases/9542'),
      hasLength(1),
    );
  });

  test('finds nothing for a title AniLibria has not linked', () async {
    final releases = await repository().findReleases(
      shikimoriId: '1',
      titles: const ['Frieren'],
    );

    expect(releases, isEmpty);
    expect(requests.map((request) => request.path), ['/app/search/releases']);
  });

  test('a failed title does not hide what another found', () async {
    final releases =
        await repository(
          failingQueries: {'Провожающая в последний путь Фрирен'},
        ).findReleases(
          shikimoriId: _frierenShikimoriId,
          titles: const ['Провожающая в последний путь Фрирен', 'Frieren'],
        );

    expect(releases, hasLength(1));
  });

  test('a release that fails to load does not hide another', () async {
    // A second release linked to the same id, which AniLibria cannot give.
    final search = _fixture('search_frieren')! as List<Object?>;
    final frieren = search.cast<Map<String, Object?>>().firstWhere(
      (item) => item['id'] == 9542,
    );
    final releases = await repository(
      searchResults: {
        'Frieren': [
          ...search,
          {...frieren, 'id': 9999},
        ],
      },
    ).findReleases(shikimoriId: _frierenShikimoriId, titles: const ['Frieren']);

    expect(
      requests.map((request) => request.path),
      contains('/anime/releases/9999'),
    );
    expect(releases.map((release) => release.id), ['9542']);
  });

  test('fails rather than say "not there" when every search failed', () {
    expect(
      repository(failingQueries: {'Frieren'}).findReleases(
        shikimoriId: _frierenShikimoriId,
        titles: const ['Frieren'],
      ),
      throwsA(isA<NetworkRequestException>()),
    );
  });

  test('resolves an episode to fresh streams, best first', () async {
    final streams = await repository().resolveStreams(
      provider: OnlineProvider.anilibria,
      episodeId: '9a416b99-4487-4d8a-960a-461089d36cad',
    );

    expect(
      requests.single.path,
      '/anime/releases/episodes/9a416b99-4487-4d8a-960a-461089d36cad',
    );
    expect([for (final s in streams) s.quality], [1080, 720, 480]);
    expect(streams.every((s) => s.format == OnlineStreamFormat.hls), isTrue);
    expect(
      streams.first.url,
      endsWith('/9542/1/1080/aa675e5f3fe5b528517d812182344011.m3u8'),
    );
  });
}
