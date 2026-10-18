import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/online_sources/data/datasources/animejoy_data_source.dart';
import 'package:iris/features/online_sources/data/models/video_link_dto.dart';
import 'package:iris/features/online_sources/data/repositories/animejoy_online_sources_repository.dart';
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

  test(
    'search follows DLE pages before matching the exact Shikimori title',
    () async {
      final animejoy = source((options) async {
        requests.add(options);
        final uri = options.uri;
        if (uri.path == '/index.php' && uri.queryParameters['do'] == 'search') {
          return FakeReply.text(
            200,
            switch (uri.queryParameters['search_start']) {
              null => _searchPage([1314], next: 2),
              '2' => _searchPage([1315], next: 3),
              '3' => _searchPage([1316]),
              _ => '<div id="dle-content"></div>',
            },
          );
        }
        if (uri.path == '/index.php' && uri.queryParameters['newsid'] != null) {
          final shikimoriId = uri.queryParameters['newsid'] == '1316'
              ? 11757
              : 11756;
          return FakeReply.text(200, _articlePage(shikimoriId));
        }
        if (uri.path == '/engine/ajax/playlists.php') {
          return FakeReply.text(200, readFixture('animejoy/playlists.json'));
        }
        return const FakeReply.text(500, 'unexpected request');
      });

      final releases = await AnimejoyOnlineSourcesRepository(
        dataSource: animejoy,
      ).findReleases(shikimoriId: '11757', titles: const ['Example title']);

      expect(releases.map((release) => release.id), ['1316']);
      final searchRequests = requests
          .where((request) => request.uri.queryParameters['do'] == 'search')
          .toList();
      expect(searchRequests.map((request) => request.uri.queryParameters), [
        {'story': 'Example title', 'do': 'search', 'subaction': 'search'},
        {
          'story': 'Example title',
          'do': 'search',
          'subaction': 'search',
          'search_start': '2',
        },
        {
          'story': 'Example title',
          'do': 'search',
          'subaction': 'search',
          'search_start': '3',
        },
      ]);
      expect(
        requests
            .where(
              (request) => request.uri.path == '/engine/ajax/playlists.php',
            )
            .map((request) => request.uri.queryParameters['news_id']),
        ['1316'],
      );
    },
  );

  test(
    'repository keeps an exact playable match when a later page fails',
    () async {
      final animejoy = source((options) async {
        requests.add(options);
        final uri = options.uri;
        if (uri.path == '/index.php' && uri.queryParameters['do'] == 'search') {
          if (uri.queryParameters['search_start'] == null) {
            return FakeReply.text(200, _searchPage([5682], next: 2));
          }
          return const FakeReply.text(503, 'temporarily unavailable');
        }
        if (uri.path == '/index.php' && uri.queryParameters['newsid'] != null) {
          return FakeReply.text(200, _articlePage(11757));
        }
        if (uri.path == '/engine/ajax/playlists.php') {
          return FakeReply.text(200, readFixture('animejoy/playlists.json'));
        }
        return const FakeReply.text(500, 'unexpected request');
      });

      final releases = await AnimejoyOnlineSourcesRepository(
        dataSource: animejoy,
      ).findReleases(shikimoriId: '11757', titles: const ['Example title']);

      expect(releases.map((release) => release.id), ['5682']);
      expect(
        requests.where(
          (request) => request.uri.queryParameters['do'] == 'search',
        ),
        hasLength(2),
      );
    },
  );

  test('search stops when a repeated page adds no new article ids', () async {
    final animejoy = source((options) async {
      requests.add(options);
      return FakeReply.text(
        200,
        _searchPage([
          5682,
        ], next: options.uri.queryParameters['search_start'] == null ? 2 : 3),
      );
    });

    expect(await animejoy.search('Example title'), [5682]);
    expect(
      requests.map((request) => request.uri.queryParameters['search_start']),
      [null, '2'],
    );
  });

  for (final (name, onclick) in [
    ('invalid', 'javascript:list_submit(nope); return(false);'),
    ('backward', 'javascript:list_submit(1); return(false);'),
  ]) {
    test('search ignores a $name next-page marker', () async {
      final animejoy = source((options) async {
        requests.add(options);
        return FakeReply.text(200, _searchPage([5682], onclick: onclick));
      });

      expect(await animejoy.search('Example title'), [5682]);
      expect(requests, hasLength(1));
    });
  }

  test('search propagates a later-page failure', () async {
    final animejoy = source((options) async {
      requests.add(options);
      if (options.uri.queryParameters['search_start'] == null) {
        return FakeReply.text(200, _searchPage([5682], next: 2));
      }
      return const FakeReply.text(503, 'temporarily unavailable');
    });

    await expectLater(
      animejoy.search('Example title'),
      throwsA(isA<RemoteResponseException>()),
    );
    expect(requests, hasLength(2));
  });

  test(
    'nested player ranges preserve arbitrary translations and mirrors',
    () async {
      final animejoy = source(
        (_) async => const FakeReply(200, {
          'success': true,
          'response': '''
        <div class="playlists-lists"><div class="playlists-items"><ul>
          <li data-id="0_0">North Star 12</li>
          <li data-id="0_1">Studio 42</li>
          <li data-id="0_0_0">Наш плеер</li>
          <li data-id="0_0_1">AllVideo</li>
          <li data-id="0_0_2">Kodik</li>
          <li data-id="0_0_0_0">1-10</li>
          <li data-id="0_0_0_1">11-20</li>
          <li data-id="0_1_0">AllVideo</li>
        </ul></div></div>
        <div class="playlists-videos"><div class="playlists-items"><ul>
          <li data-id="0_0_0_1" data-file="https://animejoya.ru/player/playerjs.html?file=[1080p]https://cdn.example/north12.mp4">12 серия</li>
          <li data-id="0_0_0_0" data-file="https://animejoya.ru/player/playerjs.html?file=[720p]https://cdn.example/north1.mp4">1 серия</li>
          <li data-id="0_0_1_1" data-file="https://fsst.online/embed/north12/">12 серия</li>
          <li data-id="0_0_2_0" data-file="https://fsst.online/embed/not-allvideo/">2 серия</li>
          <li data-id="0_1_0_0" data-file="https://fsst.online/embed/studio12/">12 серия</li>
          <li data-id="0_00_0" data-file="https://fsst.online/embed/wrong-prefix/">3 серия</li>
          <li data-id="0_0_1_1" data-file="https://fsst.online/embed/recap/">Рекап</li>
        </ul></div></div>
      ''',
        }),
      );

      final episodes = await animejoy.episodes(100);
      expect(episodes.map((e) => (e.translation, e.number)), [
        ('North Star', 1),
        ('North Star', 12),
        ('Studio 42', 12),
      ]);
      expect(episodes[1].playerUrls, [
        contains('north12.mp4'),
        'https://fsst.online/embed/north12/',
      ]);
      expect(episodes[1].bestQuality, 1080);
      expect(episodes[2].playerUrls, ['https://fsst.online/embed/studio12/']);
    },
  );

  test('unnamed ranges stay unnamed and do not become translations', () async {
    final animejoy = source(
      (_) async => const FakeReply(200, {
        'success': true,
        'response': '''
        <div class="playlists-lists"><div class="playlists-items"><ul>
          <li data-id="0_0">201-400</li>
          <li data-id="0_0_0">AllVideo</li>
          <li data-id="0_0_0_0">201-210</li>
        </ul></div></div>
        <div class="playlists-videos"><div class="playlists-items"><ul>
          <li data-id="0_0_0_0" data-file="https://fsst.online/embed/201/">201 серия</li>
        </ul></div></div>
      ''',
      }),
    );
    final episodes = await animejoy.episodes(100);
    expect(episodes.single.translation, '');
    expect(episodes.single.number, 201);
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
      expect(episodes.map((episode) => episode.bestQuality), [
        1080,
        null,
        null,
      ]);
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

  for (final (file, quality) in [
    (Uri.encodeComponent('[1080p]https://cdn.example/video.mp4'), 1080),
    ('https://cdn.example/1080p.mp4', null),
    ('[2160p]javascript:alert(1),[720p]https://cdn.example/video.mp4', 720),
    ('https%3A%2F%2Fcdn.example%2F%FF.mp4', null),
  ]) {
    test('playlist quality uses only playable explicit links: $file', () async {
      final animejoy = source((options) async {
        requests.add(options);
        return FakeReply(200, {
          'success': true,
          'response':
              '''
            <div class="playlists-lists"><div class="playlists-items">
              <li data-id="our">Наш плеер</li><li data-id="all">AllVideo</li>
            </div></div>
            <div class="playlists-videos"><div class="playlists-items">
              <li data-id="our" data-file="https://animejoya.ru/player/playerjs.html?file=$file">1 серия</li>
              <li data-id="all" data-file="https://fsst.online/embed/1/">1 серия</li>
            </div></div>
          ''',
        });
      });

      final episode = (await animejoy.episodes(5682)).single;
      expect(episode.bestQuality, quality);
      expect(episode.playerUrls, hasLength(2));
      expect(requests.single.uri.path, '/engine/ajax/playlists.php');
    });
  }

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

String _searchPage(List<int> ids, {int? next, String? onclick}) {
  final articles = ids
      .map(
        (id) =>
            '''
          <article class="shortstory">
            <h2><a href="/tv-serialy/$id-title.html">Title</a></h2>
          </article>
          ''',
      )
      .join('\n');
  final marker =
      onclick ??
      (next == null ? null : 'javascript:list_submit($next); return(false);');
  final navigation = marker == null
      ? ''
      : '''
          <div class="block navigation">
            <div class="page_next-prev">
              <span class="page_next">
                <a id="nextlink" onclick="$marker" href="#">Next</a>
              </span>
            </div>
          </div>
          ''';
  return '<div id="dle-content">$articles$navigation</div>';
}

String _articlePage(int shikimoriId) =>
    '''
    <div class="abasel">
      <a href="https://shikimori.me/animes/$shikimoriId-title">Title</a>
    </div>
    ''';
