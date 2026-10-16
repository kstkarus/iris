import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/online_sources/data/datasources/animejoy_data_source.dart';
import 'package:iris/features/online_sources/data/models/video_link_dto.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/video_server_dio_factory.dart';

import '../../../../helpers/fake_http_adapter.dart';

void main() {
  late List<RequestOptions> requests;

  AnimejoyDataSource source(Future<FakeReply> Function(RequestOptions) reply) {
    final adapter = FakeHttpAdapter(reply);
    final dio = createVideoServerDio()..httpClientAdapter = adapter;
    return AnimejoyDataSource(dio: dio, baseUrl: 'https://otakujoy.fun/');
  }

  setUp(() => requests = []);

  test('search uses DLE and reads only deduplicated title links', () async {
    final animejoy = source((options) async {
      requests.add(options);
      return FakeReply.text(200, readFixture('animejoy/search.html'));
    });

    expect(await animejoy.search('Tougen Anki'), [5682, 5287]);
    expect(requests.single.uri.path, '/index.php');
    expect(requests.single.uri.queryParameters, {
      'story': 'Tougen Anki',
      'do': 'search',
      'subaction': 'search',
    });
  });

  test('article reads Shikimori only from the metadata list', () async {
    final animejoy = source((options) async {
      requests.add(options);
      return FakeReply.text(200, readFixture('animejoy/article.html'));
    });

    final article = await animejoy.article(5682);
    expect(article.id, 5682);
    expect(article.shikimoriId, 63181);
    expect(requests.single.uri.queryParameters, {'newsid': '5682'});
  });

  test(
    'playlists merge supported players by episode label and sort numerically',
    () async {
      final animejoy = source((options) async {
        requests.add(options);
        return FakeReply.text(200, readFixture('animejoy/playlists.json'));
      });

      final episodes = await animejoy.episodes(5682);

      expect(episodes.map((episode) => episode.number), [1, 1.5, 2]);
      expect(episodes.map((episode) => episode.title), ['', '', '']);
      expect(episodes[0].playerUrls, [
        startsWith('https://animejoya.ru/player/playerjs.html?file='),
        'https://fsst.online/embed/episode-1/',
      ]);
      expect(episodes[1].playerUrls, [
        'https://animejoya.ru/player/playerjs.html?file=https://cdn.example/15.mp4',
        'https://fsst.online/embed/episode-15/',
      ]);
      expect(episodes[2].playerUrls, ['https://fsst.online/embed/episode-2/']);
      expect(requests.single.uri.path, '/engine/ajax/playlists.php');
      expect(requests.single.uri.queryParameters, {
        'news_id': '5682',
        'xfield': 'playlist',
      });
    },
  );

  test(
    'own player links preserve embedded URL escapes and sort quality',
    () async {
      final animejoy = source((options) async {
        requests.add(options);
        return const FakeReply.text(500, 'unexpected request');
      });

      final links = await animejoy.links(
        'https://animejoya.ru/player/playerjs.html?file='
        '[720p]https://cdn.example/video%2F720.mp4,'
        '[1080p]https://cdn.example/video%2F1080.mp4',
      );

      expect(requests, isEmpty);
      expect(links.map((link) => link.quality), [1080, 720]);
      expect(links.first.kind, VideoLinkKind.mp4);
      expect(links.first.url, 'https://cdn.example/video%2F1080.mp4');
    },
  );

  test(
    'AllVideo parses only top-level file and accepts a trailing slash',
    () async {
      final animejoy = source((options) async {
        requests.add(options);
        return FakeReply.text(200, readFixture('animejoy/allvideo.html'));
      });

      final links = await animejoy.links('https://fsst.online/embed/1050953/');

      expect(requests.single.uri.host, 'fsst.online');
      expect(links.map((link) => link.quality), [1080, 360]);
      expect(links.every((link) => link.kind == VideoLinkKind.mp4), isTrue);
      expect(links.first.url, 'https://media.example/get_file/episode.mp4/');
      expect(links.any((link) => link.url.contains('ads.example')), isFalse);
    },
  );

  test('unlabelled player file uses its declared default quality', () async {
    final animejoy = source((options) async {
      requests.add(options);
      return const FakeReply.text(
        200,
        "<script>new Playerjs({id:'Video1065442',file:'https://cdn.example/episode.mp4/',"
        "default_quality:'480p',preroll:'https://ads.example/ad.mp4'});</script>",
      );
    });

    final links = await animejoy.links('https://fsst.online/embed/single/');

    expect(links, hasLength(1));
    expect(links.single.url, 'https://cdn.example/episode.mp4/');
    expect(links.single.quality, 480);
    expect(links.single.kind, VideoLinkKind.mp4);
  });

  test('decodes an encoded outer player query once', () async {
    final animejoy = source((options) async {
      requests.add(options);
      return const FakeReply.text(500, 'unexpected request');
    });

    final links = await animejoy.links(
      'https://animejoya.ru/player/playerjs.html?file='
      '%5B1080p%5Dhttps%3A%2F%2Fcdn.example%2Fvideo%252F1080.mp4',
    );

    expect(links.single.url, 'https://cdn.example/video%2F1080.mp4');
  });

  test('skips a separate ad player and decodes escaped content URLs', () async {
    final animejoy = source(
      (options) async => const FakeReply.text(200, r'''
      <script>
        new Playerjs({id:'AdPlayer', file:'[1080p]https://ads.example/ad.mp4'});
        new Playerjs({
          id: 'Video1050953',
          'preroll': {file:'https://ads.example/preroll.mp4'},
          "file": "[1080p]https:\/\/media.example\/video.mp4?token=a\u0026key=b",
          default_quality: '1080p'
        });
      </script>
    '''),
    );

    final links = await animejoy.links('https://fsst.online/embed/1050953/');
    expect(links, hasLength(1));
    expect(links.single.url, 'https://media.example/video.mp4?token=a&key=b');
  });

  test('keeps an explicitly numbered episode zero', () async {
    final animejoy = source(
      (options) async => FakeReply.text(
        200,
        readFixture(
          'animejoy/playlists.json',
        ).replaceAll('1.5 серия', '0 серия'),
      ),
    );
    final episodes = await animejoy.episodes(5682);
    expect(episodes.map((episode) => episode.number), [0, 1, 2]);
  });

  test('rejects non-http media URLs', () async {
    final animejoy = source((options) async {
      requests.add(options);
      return const FakeReply.text(500, 'unexpected request');
    });

    expect(
      await animejoy.links(
        'https://animejoya.ru/player/playerjs.html?file='
        '[1080p]javascript:alert(1),[720p]data:video/mp4',
      ),
      isEmpty,
    );
  });

  test('maps malformed playlist JSON to an app response failure', () {
    final animejoy = source((options) async {
      requests.add(options);
      return const FakeReply.text(200, '{broken');
    });

    expect(animejoy.episodes(5682), throwsA(isA<RemoteResponseException>()));
  });
}
