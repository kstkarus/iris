import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/data/adapters/online_episode_downloader.dart';
import 'package:iris/features/online_sources/data/datasources/animejoy_data_source.dart';
import 'package:iris/features/online_sources/data/repositories/animejoy_online_sources_repository.dart';
import 'package:iris/features/online_sources/data/repositories/combined_online_sources_repository.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/player/data/repositories/online_player_repository.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/shared/network/video_server_dio_factory.dart';
import 'package:iris/shared/online/online_source_link.dart';

import '../../../../helpers/fake_http_adapter.dart';

const _animeId = '63181';

void main() {
  test(
    'merges unnamed parts and keeps arbitrary translations independent',
    () async {
      final site = _FakeAnimejoySite(
        searchIds: [300, 201, 200],
        playlists: {
          200: _playlist(200, {
            '': {200: 'article-200-episode-200'},
          }),
          201: _playlist(201, {
            '': {201: 'article-201-episode-201'},
          }),
          300: _playlist(300, {
            '  Skylight   Audio  ': {200: 'article-300-group-0-episode-200'},
            'River   Studio': {200: 'article-300-group-1-episode-200'},
          }),
        },
      );
      final repository = site.repository();
      final releases = await repository.findReleases(
        shikimoriId: _animeId,
        titles: const ['Example'],
      );

      expect(releases, hasLength(3));
      final unnamed = releases.singleWhere(
        (release) => release.dub == 'AnimeJoy',
      );
      expect(unnamed.id, 'parts:200,201:');
      expect(unnamed.episodes.map((episode) => episode.number), [200, 201]);
      expect(unnamed.episodes.map((episode) => episode.id), [
        '200:200',
        '201:201',
      ]);

      final skylight = releases.singleWhere(
        (release) => release.dub == 'AnimeJoy · Skylight Audio',
      );
      final river = releases.singleWhere(
        (release) => release.dub == 'AnimeJoy · River Studio',
      );
      expect(skylight.id, 'parts:300:skylight%20audio');
      expect(river.id, 'parts:300:river%20studio');
      expect(skylight.episodes.single.id, '300:200:skylight%20audio');
      expect(river.episodes.single.id, '300:200:river%20studio');
      for (final selected in [skylight, river]) {
        final saved = OnlineSourceLink.tryParse(
          OnlineSourceLink(
            provider: 'animejoy',
            releaseId: selected.id,
            animeId: _animeId,
          ).toString(),
        )!;
        final reopened = await site.repository().fetchRelease(
          provider: OnlineProvider.animejoy,
          id: saved.releaseId,
        );
        expect(reopened, selected);
        expect(saved.progressKey, 'online:anime/$_animeId');
      }
      expect(
        (await repository.resolveStreams(
          provider: OnlineProvider.animejoy,
          episodeId: skylight.episodes.single.id,
        )).single.url,
        'https://cdn.example/article-300-group-0-episode-200.mp4',
      );
      expect(
        (await repository.resolveStreams(
          provider: OnlineProvider.animejoy,
          episodeId: river.episodes.single.id,
        )).single.url,
        'https://cdn.example/article-300-group-1-episode-200.mp4',
      );
    },
  );

  test(
    'a serialized split link works in a fresh player and downloads its selected part',
    () async {
      final site = _FakeAnimejoySite(
        searchIds: [201, 200],
        playlists: {
          200: _playlist(200, {
            '': {200: 'article-200-episode-200'},
          }),
          201: _playlist(201, {
            '': {201: 'article-201-episode-201'},
          }),
        },
      );
      final discovered = await site.repository().findReleases(
        shikimoriId: _animeId,
        titles: const ['Example'],
      );
      final link = OnlineSourceLink(
        provider: OnlineProvider.animejoy.name,
        releaseId: discovered.single.id,
        animeId: _animeId,
      );
      final restored = OnlineSourceLink.tryParse(link.toString())!;
      final freshRepository = site.repository();
      final player = OnlinePlayerRepository(repository: freshRepository);
      final prepared = await player.prepareSource(magnet: link.toString());
      expect(prepared.files.map((file) => file.index), [200, 201]);

      final updates = await player
          .startPlayback(sessionId: link.toString(), fileIndex: 201)
          .toList();
      final session = (updates.single as PlayerLaunchReadyUpdate).session;
      expect(
        session.streamUrl,
        'https://cdn.example/article-201-episode-201.mp4',
      );
      await player.disposePlayback(sessionId: session.sessionId);
      expect(
        site.requests.where(
          (request) => request.uri.queryParameters.containsKey('story'),
        ),
        hasLength(1),
      );

      final directory = await Directory.systemTemp.createTemp(
        'iris_animejoy_split_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final downloader = OnlineEpisodeDownloader(
        repository: freshRepository,
        dio: site.downloadDio(),
      );
      final task = downloader.start(
        link: restored,
        fileIndex: 201,
        directory: directory,
        maxQuality: 720,
      );
      final file = await task.done;
      expect(
        await file!.readAsString(),
        'payload:/article-201-episode-201.mp4',
      );
      expect(
        site.requests.any(
          (request) =>
              request.uri.toString() ==
              'https://cdn.example/article-201-episode-201.mp4',
        ),
        isTrue,
      );
    },
  );

  test('legacy numeric release ids still launch', () async {
    final site = _FakeAnimejoySite(
      searchIds: [500],
      playlists: {
        500: _playlist(500, {
          '': {1: 'article-500-episode-1'},
        }),
      },
    );
    const link = OnlineSourceLink(
      provider: 'animejoy',
      releaseId: '500',
      animeId: _animeId,
    );
    final player = OnlinePlayerRepository(repository: site.repository());
    final updates = await player
        .startPlayback(sessionId: link.toString(), fileIndex: 1)
        .toList();
    final session = (updates.single as PlayerLaunchReadyUpdate).session;
    expect(session.streamUrl, 'https://cdn.example/article-500-episode-1.mp4');
  });
}

String _playlist(int articleId, Map<String, Map<int, String>> groups) {
  final tabs = StringBuffer(
    '<div class="playlists-lists"><div class="playlists-items"><ul>',
  );
  final videos = StringBuffer(
    '<div class="playlists-videos"><div class="playlists-items"><ul>',
  );
  var groupIndex = 0;
  for (final group in groups.entries) {
    final translationId = '0_$groupIndex';
    final playerId = group.key.isEmpty ? translationId : '${translationId}_0';
    final videoId = group.key.isEmpty ? playerId : '${playerId}_0';
    if (group.key.isEmpty) {
      tabs.write('<li data-id="$playerId">Наш плеер</li>');
    } else {
      tabs.write(
        '<li data-id="$translationId">${group.key}<ul>'
        '<li data-id="$playerId">Наш плеер</li></ul></li>',
      );
    }
    for (final episode in group.value.entries) {
      videos.write(
        '<li data-id="$videoId" data-file="https://animejoya.ru/player/playerjs.html?file=%5B720p%5Dhttps%3A%2F%2Fcdn.example%2F${episode.value}.mp4">'
        '${episode.key} серия</li>',
      );
    }
    groupIndex++;
  }
  return '${tabs.toString()}</ul></div></div>'
      '${videos.toString()}</ul></div></div>';
}

class _FakeAnimejoySite {
  _FakeAnimejoySite({required this.searchIds, required this.playlists});

  final List<int> searchIds;
  final Map<int, String> playlists;
  final requests = <RequestOptions>[];

  CombinedOnlineSourcesRepository repository() {
    final dio = createVideoServerDio()
      ..httpClientAdapter = FakeHttpAdapter(reply);
    return CombinedOnlineSourcesRepository(
      providers: {
        OnlineProvider.animejoy: AnimejoyOnlineSourcesRepository(
          dataSource: AnimejoyDataSource(dio: dio),
        ),
      },
    );
  }

  Dio downloadDio() => fakeDio(reply);

  FakeReply reply(RequestOptions options) {
    requests.add(options);
    final uri = options.uri;
    if (uri.host == 'animejoy.ru' && uri.path == '/index.php') {
      if (uri.queryParameters.containsKey('story')) {
        return FakeReply.text(
          200,
          '<div id="dle-content">${[for (final id in searchIds) '<article class="shortstory"><h2><a href="https://animejoy.ru/$id-title.html">Example</a></h2></article>'].join()}</div>',
        );
      }
      final id = int.tryParse(uri.queryParameters['newsid'] ?? '');
      if (id != null && playlists.containsKey(id)) {
        return const FakeReply.text(
          200,
          '<div class="abasel"><a href="https://shikimori.one/animes/63181-example">Shikimori</a></div>',
        );
      }
    }
    if (uri.host == 'animejoy.ru' && uri.path == '/engine/ajax/playlists.php') {
      final id = int.tryParse(uri.queryParameters['news_id'] ?? '');
      final response = id == null ? null : playlists[id];
      if (response != null) {
        return FakeReply(200, {'success': true, 'response': response});
      }
    }
    if (uri.host == 'cdn.example') {
      final payload = 'payload:${uri.path}';
      return FakeReply.text(
        200,
        payload,
        headers: {
          'content-length': ['${payload.length}'],
        },
      );
    }
    return FakeReply.text(404, 'Unexpected request');
  }
}
