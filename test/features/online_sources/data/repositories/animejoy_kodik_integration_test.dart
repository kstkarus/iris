import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/data/adapters/online_episode_downloader.dart';
import 'package:iris/features/online_sources/data/datasources/animejoy_data_source.dart';
import 'package:iris/features/online_sources/data/repositories/animejoy_online_sources_repository.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/player/data/repositories/online_player_repository.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/video_server_dio_factory.dart';
import 'package:iris/shared/online/online_source_link.dart';

import '../../../../helpers/fake_http_adapter.dart';

void main() {
  test(
    'prefers both existing players even when Kodik has higher quality',
    () async {
      final site = _FakeSite();
      final repository = site.repository();
      final releases = await repository.findReleases(
        shikimoriId: '42310',
        titles: const ['Cyberpunk'],
      );
      final nf = releases.singleWhere(
        (release) => release.dub == 'AnimeJoy · NF',
      );
      expect(nf.id, 'parts:2927:nf');
      expect(nf.episodes.map((episode) => episode.number), [5, 6, 366]);
      expect(
        releases
            .singleWhere((release) => release.dub == 'AnimeJoy · AL')
            .episodes
            .single
            .number,
        5,
      );

      site.requests.clear();
      final streams = await repository.resolveStreams(
        provider: OnlineProvider.animejoy,
        episodeId: '2927:5:nf',
      );
      expect(streams.map((stream) => stream.quality), [480, 480]);
      expect(streams.map((stream) => stream.url), [
        'https://cdn.example/own-5.mp4',
        'https://cdn.example/allvideo-5.mp4',
      ]);
      expect(
        site.requests.any((request) => request.uri.host == 'kodikplayer.com'),
        isFalse,
      );
    },
  );

  test('uses Kodik only when the preferred players have no links', () async {
    final site = _FakeSite(preferredAvailable: false);
    final repository = site.repository();
    final streams = await repository.resolveStreams(
      provider: OnlineProvider.animejoy,
      episodeId: '2927:5:nf',
    );
    expect(streams.map((stream) => stream.quality), [720, 480, 360]);
    expect(site.episodeRequests, [5]);
    expect(
      site.requests.where((request) => request.uri.path == '/ftor'),
      hasLength(1),
    );
  });

  test(
    'reopens the requested Kodik episode on every switch and renewal',
    () async {
      final site = _FakeSite(preferredAvailable: false);
      final repository = site.repository();
      final player = OnlinePlayerRepository(repository: repository);
      final link = const OnlineSourceLink(
        provider: 'animejoy',
        releaseId: 'parts:2927:nf',
        animeId: '42310',
      ).toString();
      final prepared = await player.prepareSource(magnet: link);
      expect(prepared.files.map((file) => file.index), [5, 6, 366]);

      for (final number in [5, 6, 5, 6]) {
        await player.stopPlayback(sessionId: link);
        final updates = await player
            .startPlayback(sessionId: link, fileIndex: number)
            .toList();
        expect(updates.single, isA<PlayerLaunchReadyUpdate>());
      }
      expect(site.episodeRequests, [5, 6, 5, 6]);
      await player.disposePlayback(sessionId: link);
    },
  );

  test(
    'does not merge an unnamed player with an unconfirmed Kodik translation',
    () async {
      final site = _FakeSite(
        namedTranslation: false,
        preferredAvailable: false,
      );
      final repository = site.repository();
      final releases = await repository.findReleases(
        shikimoriId: '42310',
        titles: const ['Cyberpunk'],
      );
      final normal = releases.singleWhere(
        (release) => release.dub == 'AnimeJoy',
      );
      final kodik = releases.singleWhere(
        (release) => release.dub == 'AnimeJoy · Netflix.Subtitles',
      );
      expect(normal.id, '2927');
      expect(kodik.id, 'parts:2927:kodik-1946');
      expect(
        (await repository.fetchRelease(
          provider: OnlineProvider.animejoy,
          id: kodik.id,
        )).episodes,
        kodik.episodes,
      );
      expect(
        await repository.resolveStreams(
          provider: OnlineProvider.animejoy,
          episodeId: '2927:5',
        ),
        isEmpty,
      );
      expect(site.episodeRequests, isEmpty);
    },
  );

  test(
    'downloads a Kodik fallback through the existing HLS downloader',
    () async {
      final site = _FakeSite(preferredAvailable: false);
      final directory = await Directory.systemTemp.createTemp(
        'iris_animejoy_kodik_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final downloader = OnlineEpisodeDownloader(
        repository: site.repository(),
        dio: fakeDio(site.reply),
      );
      final task = downloader.start(
        link: const OnlineSourceLink(
          provider: 'animejoy',
          releaseId: 'parts:2927:nf',
          animeId: '42310',
        ),
        fileIndex: 6,
        directory: directory,
        maxQuality: 720,
      );
      final file = await task.done;
      expect(await file!.readAsString(), 'episode segment');
      expect(site.episodeRequests, [6]);
    },
  );

  test('keeps preferred sources when Kodik catalog is unavailable', () async {
    final site = _FakeSite(failKodikCatalog: true);
    final repository = site.repository();
    final releases = await repository.findReleases(
      shikimoriId: '42310',
      titles: const ['Cyberpunk'],
    );
    final nf = releases.singleWhere(
      (release) => release.dub == 'AnimeJoy · NF',
    );
    expect(nf.episodes.map((episode) => episode.number), [5]);
    expect(
      (await repository.resolveStreams(
        provider: OnlineProvider.animejoy,
        episodeId: '2927:5:nf',
      )).first.url,
      'https://cdn.example/own-5.mp4',
    );
  });

  test('keeps the translation id when Kodik adds later episodes', () async {
    final site = _FakeSite(counterLabel: true);
    final releases = await site.repository().findReleases(
      shikimoriId: '42310',
      titles: const ['Cyberpunk'],
    );
    final nf = releases.singleWhere(
      (release) => release.dub == 'AnimeJoy · NF',
    );
    expect(nf.id, 'parts:2927:nf');
    expect(nf.episodes.map((episode) => episode.number), [5, 6, 366]);

    final offline = _FakeSite(counterLabel: true, failKodikCatalog: true);
    final release = await offline.repository().fetchRelease(
      provider: OnlineProvider.animejoy,
      id: nf.id,
    );
    expect(release.episodes.map((episode) => episode.number), [5]);
    final streams = await offline.repository().resolveStreams(
      provider: OnlineProvider.animejoy,
      episodeId: release.episodes.single.id,
    );
    expect(streams.first.url, 'https://cdn.example/own-5.mp4');
  });

  test(
    'does not play a different episode when Kodik returns the wrong id',
    () async {
      final site = _FakeSite(preferredAvailable: false, wrongEpisode: true);
      await expectLater(
        site.repository().resolveStreams(
          provider: OnlineProvider.animejoy,
          episodeId: '2927:6:nf',
        ),
        throwsA(isA<ResourceNotFoundException>()),
      );
      expect(
        site.requests.any((request) => request.uri.path == '/ftor'),
        isFalse,
      );
    },
  );
}

class _FakeSite {
  _FakeSite({
    this.namedTranslation = true,
    this.preferredAvailable = true,
    this.failKodikCatalog = false,
    this.wrongEpisode = false,
    this.counterLabel = false,
  });

  final bool namedTranslation;
  final bool preferredAvailable;
  final bool failKodikCatalog;
  final bool wrongEpisode;
  final bool counterLabel;
  final requests = <RequestOptions>[];

  List<int> get episodeRequests => [
    for (final request in requests)
      if (request.uri.host == 'kodikplayer.com' &&
          request.uri.path.startsWith('/serial/') &&
          request.uri.queryParameters.containsKey('episode'))
        int.parse(request.uri.queryParameters['episode']!),
  ];

  AnimejoyOnlineSourcesRepository repository() {
    final dio = createVideoServerDio()
      ..httpClientAdapter = FakeHttpAdapter(reply);
    return AnimejoyOnlineSourcesRepository(
      dataSource: AnimejoyDataSource(dio: dio),
    );
  }

  FakeReply reply(RequestOptions request) {
    requests.add(request);
    final uri = request.uri;
    if (uri.host == 'animejoy.ru' && uri.path == '/index.php') {
      if (uri.queryParameters.containsKey('story')) {
        return const FakeReply.text(
          200,
          '<div id="dle-content"><article class="shortstory"><h2><a href="https://animejoy.ru/2927-title.html">Cyberpunk</a></h2></article></div>',
        );
      }
      return const FakeReply.text(
        200,
        '<div class="abasel"><a href="https://shikimori.io/animes/y42310-cyberpunk">Shikimori</a></div>',
      );
    }
    if (uri.host == 'animejoy.ru' && uri.path == '/engine/ajax/playlists.php') {
      return FakeReply(200, {'success': true, 'response': _playlist()});
    }
    if (uri.host == 'fsst.online') {
      final file = preferredAvailable
          ? '[480p]https://cdn.example/allvideo-5.mp4'
          : 'https://cdn.example/not-a-video';
      return FakeReply.text(
        200,
        '<script>new Playerjs({id:"Video1",file:"$file"});</script>',
      );
    }
    if (uri.host == 'kodikplayer.com' && uri.path.startsWith('/serial/')) {
      final episode = uri.queryParameters['episode'];
      if (episode == null) {
        if (failKodikCatalog) return const FakeReply.text(503, 'offline');
        return const FakeReply.text(200, _catalog);
      }
      final id = switch (episode) {
        '5' => '1211977',
        '6' when !wrongEpisode => '1211978',
        '366' => '1212338',
        _ => '1211977',
      };
      return FakeReply.text(
        200,
        readFixture('kodik/page.html').replaceAll('1211977', id),
      );
    }
    if (uri.host == 'kodikplayer.com' && uri.path.startsWith('/assets/js/')) {
      return FakeReply.text(200, readFixture('kodik/player.js'));
    }
    if (uri.host == 'kodikplayer.com' && uri.path == '/ftor') {
      return FakeReply.text(200, readFixture('kodik/api.json'));
    }
    if (uri.host == 'cdn.example.test') {
      return uri.path.endsWith('.m3u8')
          ? const FakeReply.text(
              200,
              '#EXTM3U\n#EXTINF:6,\nsegment.ts\n#EXT-X-ENDLIST',
            )
          : const FakeReply.text(200, 'episode segment');
    }
    return const FakeReply.text(404, 'Unexpected request');
  }

  String _playlist() {
    final ownId = namedTranslation ? '0_0_0' : '0_0';
    final allId = namedTranslation ? '0_0_1' : '0_1';
    final kodikId = namedTranslation ? '0_0_2' : '0_2';
    final own = preferredAvailable
        ? '[480p]https://cdn.example/own-5.mp4'
        : 'https://cdn.example/not-a-video';
    final tabs =
        '<li data-id="$ownId">Наш плеер</li>'
        '<li data-id="$allId">AllVideo</li>'
        '<li data-id="$kodikId">Kodik</li>';
    final grouped = namedTranslation
        ? '<li data-id="0_0">${counterLabel ? 'NF 5' : 'NF'}<ul>$tabs</ul></li>'
              '<li data-id="0_1">AL<ul><li data-id="0_1_0">Наш плеер</li></ul></li>'
        : tabs;
    return '<div class="playlists-lists"><div class="playlists-items"><ul>$grouped</ul></div></div>'
        '<div class="playlists-videos"><div class="playlists-items"><ul>'
        '<li data-id="${ownId}_0" data-file="https://animejoya.ru/player/playerjs.html?file=$own">5 серия</li>'
        '<li data-id="${allId}_0" data-file="https://fsst.online/embed/5">5 серия</li>'
        '<li data-id="$kodikId" data-file="https://kodikplayer.com/serial/33316/deadbeef/720p">TV</li>'
        '${namedTranslation ? '<li data-id="0_1_0_0" data-file="https://animejoya.ru/player/playerjs.html?file=https://cdn.example/al-5.mp4">5 серия</li>' : ''}'
        '</ul></div></div>';
  }
}

const _catalog = '''
<div class="serial-translations-box"><select>
  <option data-id="609" data-title="Voice" data-translation-type="voice">Voice</option>
  <option data-id="1946" data-title="Netflix.Subtitles" data-translation-type="subtitles" selected>Subtitles</option>
</select></div>
<div class="serial-series-box"><select>
  <option value="5" data-id="1211977" data-hash="hash5">5</option>
  <option value="6" data-id="1211978" data-hash="hash6">6</option>
  <option value="6" data-id="1211978" data-hash="hash6">6</option>
  <option value="52" data-id="1212024" data-hash="hash52" data-other-translation="true">52</option>
  <option value="366" data-id="1212338" data-hash="hash366">366</option>
</select></div>
''';
