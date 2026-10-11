import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/online_sources/data/datasources/aksor_data_source.dart';
import 'package:iris/features/online_sources/data/datasources/kodik_data_source.dart';
import 'package:iris/features/online_sources/data/datasources/yummy_anime_data_source.dart';
import 'package:iris/features/online_sources/data/mappers/yummy_anime_mapper.dart';
import 'package:iris/features/online_sources/data/repositories/yummy_anime_online_sources_repository.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/video_server_dio_factory.dart';
import 'package:iris/shared/network/yummy_anime_api_client.dart';

import '../../../../helpers/fake_http_adapter.dart';

/// Recorded from the live API (trimmed: three tracks, two episodes).
Object? _json(String name) => jsonDecode(readFixture(name));

const _frierenShikimoriId = '52991';
final _anilibriaId = '10661:${Uri.encodeComponent('Озвучка AniLibria')}';

void main() {
  late List<Uri> requests;

  YummyAnimeOnlineSourcesRepository repository({
    bool kodikDown = false,
    bool aksorDown = false,
  }) {
    final api = Dio(BaseOptions(baseUrl: 'https://api.yani.tv'))
      ..httpClientAdapter = FakeHttpAdapter((options) {
        requests.add(options.uri);
        final Object? data = switch (options.uri.path) {
          '/anime' => _json('yummy_anime/search_frieren.json'),
          '/anime/10661/videos' => _json('yummy_anime/videos_10661.json'),
          _ => null,
        };
        return data == null ? const FakeReply(404) : FakeReply(200, data);
      });
    final players = createVideoServerDio()
      ..httpClientAdapter = FakeHttpAdapter((options) {
        requests.add(options.uri);
        final uri = options.uri;
        final (int status, String body) = switch (uri.host) {
          'player.aksor.tv' when aksorDown => (503, ''),
          'player.aksor.tv' => (200, readFixture('aksor/video.json')),
          'kodikplayer.com' when kodikDown => (503, ''),
          'kodikplayer.com' when uri.path.startsWith('/assets/') => (
            200,
            readFixture('kodik/player.js'),
          ),
          'kodikplayer.com' when uri.path == '/ftor' => (
            200,
            readFixture('kodik/api.json'),
          ),
          'kodikplayer.com' => (200, readFixture('kodik/page.html')),
          _ => (404, ''),
        };
        return FakeReply.text(status, body);
      });
    return YummyAnimeOnlineSourcesRepository(
      dataSource: YummyAnimeDataSource(client: YummyAnimeApiClient(dio: api)),
      kodik: KodikDataSource(dio: players),
      aksor: AksorDataSource(dio: players),
    );
  }

  setUp(() => requests = []);

  test('makes a release of every dub of the anime with that id', () async {
    final releases = await repository().findReleases(
      shikimoriId: _frierenShikimoriId,
      titles: const ['Frieren'],
    );

    expect(requests.first.queryParameters['q'], 'Frieren');
    // The second season, another Shikimori id, is not asked for.
    expect(
      requests.where((uri) => uri.path.endsWith('/videos')).single.path,
      '/anime/10661/videos',
    );
    expect(
      releases.every((r) => r.provider == OnlineProvider.yummyAnime),
      true,
    );
    expect(
      {for (final r in releases) r.dub},
      {'AniLibria', 'AniDUB', 'Субтитры Crunchyroll'},
    );
    final anilibria = releases.firstWhere((r) => r.dub == 'AniLibria');
    expect(anilibria.id, _anilibriaId);
    expect(anilibria.bestQuality, 1080);
    expect([for (final e in anilibria.episodes) e.number], [1, 2]);
    expect(anilibria.episodes.first.duration, const Duration(minutes: 26));
    // Aksor first, then Kodik; CVH and Alloha are left out.
    final players = decodeYummyEpisodeId(anilibria.episodes.first.id);
    expect(players, hasLength(2));
    expect(players.first, startsWith('https://player.aksor.tv/video/'));
    expect(players.last, startsWith('https://kodikplayer.com/season/'));
    final anidub = releases.firstWhere((r) => r.dub == 'AniDUB');
    expect(anidub.bestQuality, 720);
  });

  test('finds nothing for an anime it has not linked', () async {
    final releases = await repository().findReleases(
      shikimoriId: '1',
      titles: const ['Frieren'],
    );

    expect(releases, isEmpty);
  });

  test('finds a dub again by its release id', () async {
    final release = await repository().fetchRelease(
      provider: OnlineProvider.yummyAnime,
      id: _anilibriaId,
    );

    expect(release.dub, 'AniLibria');
    expect(release.episodes, hasLength(2));
    expect(
      repository().fetchRelease(
        provider: OnlineProvider.yummyAnime,
        id: '10661:${Uri.encodeComponent('Озвучка Nobody')}',
      ),
      throwsA(isA<ResourceNotFoundException>()),
    );
  });

  test('resolves Aksor before Kodik', () async {
    final release = await repository().fetchRelease(
      provider: OnlineProvider.yummyAnime,
      id: _anilibriaId,
    );
    final streams = await repository().resolveStreams(
      provider: OnlineProvider.yummyAnime,
      episodeId: release.episodes.first.id,
    );

    expect(
      [for (final s in streams) (s.quality, s.format)],
      [
        (1080, OnlineStreamFormat.dash),
        (720, OnlineStreamFormat.hls),
        (480, OnlineStreamFormat.hls),
        (360, OnlineStreamFormat.hls),
      ],
    );
  });

  test('a player that is down leaves the other', () async {
    final release = await repository().fetchRelease(
      provider: OnlineProvider.yummyAnime,
      id: _anilibriaId,
    );
    final streams = await repository(aksorDown: true).resolveStreams(
      provider: OnlineProvider.yummyAnime,
      episodeId: release.episodes.first.id,
    );

    expect(streams.first.quality, 720);
  });

  test('fails when every player is down', () async {
    final release = await repository().fetchRelease(
      provider: OnlineProvider.yummyAnime,
      id: _anilibriaId,
    );

    expect(
      repository(aksorDown: true, kodikDown: true).resolveStreams(
        provider: OnlineProvider.yummyAnime,
        episodeId: release.episodes.first.id,
      ),
      throwsA(isA<RemoteResponseException>()),
    );
  });

  test('labels a voice by its studio and keeps subtitles as they are', () {
    expect(yummyDubLabel('Озвучка AniDUB'), 'AniDUB');
    expect(yummyDubLabel('Субтитры Crunchyroll'), 'Субтитры Crunchyroll');
  });
}
