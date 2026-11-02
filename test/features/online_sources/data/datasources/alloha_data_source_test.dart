import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/online_sources/data/datasources/alloha_data_source.dart';
import 'package:iris/features/online_sources/data/datasources/alloha_stream_proxy.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/video_server_dio_factory.dart';

import '../../../../helpers/fake_http_adapter.dart';

const _player = 'https://player.stravers.live/?token=example';

void main() {
  AllohaDataSource source(Map<String, Object?> fileList) {
    final page = "const fileList = JSON.parse('${jsonEncode(fileList)}');";
    final dio = createVideoServerDio()
      ..httpClientAdapter = FakeHttpAdapter((_) => FakeReply.text(200, page));
    return AllohaDataSource(dio: dio);
  }

  test(
    'reads only episodes of the selected subtitle translation and season',
    () async {
      final result = await source({
        'type': 'serial',
        'active': {
          'translation': 'Субтитры',
          'id_translation': 79,
          'seasons': 1,
        },
        'all': {
          't79': {
            'file': {
              '1': {
                '1': {
                  'id': 101,
                  'id_translation': 79,
                  'seasons': 1,
                  'episode': 1,
                },
                '3': {
                  'id': 103,
                  'id_translation': 79,
                  'seasons': 1,
                  'episode': 3,
                },
                '4': {
                  'id': 104,
                  'id_translation': 10,
                  'seasons': 1,
                  'episode': 4,
                },
              },
              '2': {
                '1': {
                  'id': 201,
                  'id_translation': 79,
                  'seasons': 2,
                  'episode': 1,
                },
              },
            },
          },
        },
      }).episodes(_player);

      expect(result?.translationId, '79');
      expect(result?.translation, 'Субтитры');
      expect(result?.videoIds, {1: 101, 3: 103});
    },
  );

  test('exposes a subtitle movie as one episode', () async {
    final result = await source({
      'type': 'movie',
      'active': {'id': 42, 'id_translation': 79, 'translation': 'Субтитры'},
    }).episodes(_player);
    expect(result?.videoIds, {1: 42});
  });

  test('does not silently switch a selected dub to subtitles', () async {
    expect(
      await source({
        'type': 'movie',
        'active': {'id': 42, 'id_translation': 10, 'translation': 'AniLibria'},
      }).episodes(_player),
      isNull,
    );
  });

  test('refuses a player URL outside the trusted Alloha hosts', () async {
    await expectLater(
      source({}).episodes('https://stravers.live.attacker.test/'),
      throwsA(isA<ResourceNotFoundException>()),
    );
  });

  test('sends only the Alloha user agent in the WebSocket handshake', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final receivedAgent = Completer<String?>();
    final sockets = <WebSocket>[];
    server.listen((request) async {
      receivedAgent.complete(request.headers.value('user-agent'));
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen(socket.add);
    });
    addTearDown(() async {
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    });
    final socket = await connectAllohaSocket(
      null,
      Uri.parse('ws://127.0.0.1:${server.port}/'),
      {'User-Agent': allohaUserAgent},
    );
    addTearDown(socket.close);
    expect(
      await receivedAgent.future,
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:159.0) '
      'Gecko/20100101 Firefox/159.0',
    );
    final echoed = socket.first;
    socket.add('ping');
    expect(await echoed, 'ping');
  });

  test('times out a stalled socket and closes a late connection', () {
    fakeAsync((clock) {
      final pending = Completer<WebSocket>();
      Object? error;
      connectAllohaSocket(
        (_, _) => pending.future,
        Uri.parse('wss://player.stravers.live/socket'),
        {},
      ).then<void>(
        (_) {},
        onError: (Object value) {
          error = value;
        },
      );
      clock.elapse(const Duration(seconds: 14));
      expect(error, isNull);
      clock.elapse(const Duration(seconds: 1));
      expect(error, isA<TimeoutException>());
      final lateSocket = _LateSocket();
      pending.complete(lateSocket);
      clock.flushMicrotasks();
      expect(lateSocket.closed, isTrue);
    });
  });

  test('opens Alloha with subtitles and falls back to video mirrors', () async {
    final socketServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final starts = <Map<String, dynamic>>[];
    socketServer.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((message) {
        starts.add(jsonDecode(message as String) as Map<String, dynamic>);
        socket.add(jsonEncode({'type': 'config_update', 'edge_hash': 'edge'}));
      });
    });
    final fileList = {
      'type': 'movie',
      'active': {'id': 42, 'id_translation': 79, 'translation': 'Субтитры'},
    };
    final page =
        '<meta name="viewporti" content="abcdefghijklmnop">'
        '<script src="/build/app.test.js"></script>'
        "<script>const fileList = JSON.parse('${jsonEncode(fileList)}');</script>";
    final guard = '${'x' * 219}+';
    const expectedFingerprint =
        '91ede163547d0d0112d23a4c99329f5ce32db756dcf3f7ab40396bd1b24dd639';
    final mediaRequests = <RequestOptions>[];
    var failFirstSegment = true;
    var failSubtitle = false;
    var partialPlaylist = false;
    var useSeparateReserve = false;
    var primaryAvailable = false;
    var multiQuality = false;
    var malformedHighPlaylist = false;
    var failHighConnection = false;
    var highPrimaryAvailable = false;
    var highBackupAvailable = true;
    var reserveUrl = 'https://cdn.example/video.m3u8';
    final dio = createVideoServerDio()
      ..httpClientAdapter = FakeHttpAdapter((request) {
        if (request.uri.host == 'player.stravers.live') {
          expect(request.headers['User-Agent'], allohaUserAgent);
          if (request.uri.path == '/build/app.test.js') {
            return FakeReply.text(200, "'$guard'");
          }
          if (request.uri.path == '/bnsi/movies/42') {
            expect(
              request.headers['Borth'].toString(),
              '$expectedFingerprint|lnhgpiacojefmkbd',
            );
            return FakeReply(200, {
              'pnr': 'wss://player.stravers.live/socket',
              'pnk': 'session',
              'hlsSource': [
                {
                  'label': '(Russian) dub',
                  'audioId': '1',
                  'quality': {
                    '720':
                        'https://badcdn.example/video.m3u8 or https://cdn.example/video.m3u8',
                  },
                },
                {
                  'label': '(Japanese) original',
                  'audioId': 6,
                  'quality': {
                    '720': useSeparateReserve
                        ? 'https://badcdn.example/video.m3u8'
                        : 'https://badcdn.example/video.m3u8 or https://cdn.example/video.m3u8',
                    if (multiQuality)
                      '1080': 'https://badcdn.example/video-1080.m3u8',
                  },
                  if (useSeparateReserve)
                    'reserve': {
                      '720': reserveUrl,
                      if (multiQuality)
                        '1080': 'https://cdn.example/video-1080.m3u8',
                    },
                },
              ],
              'tracks': [
                {
                  'kind': 'captions',
                  'language': 'rus',
                  'src': 'https://cdn.example/signs.vtt',
                  'label': 'Надписи',
                  'default': true,
                },
                {
                  'kind': 'captions',
                  'language': 'rus',
                  'src': 'https://cdn.example/full.vtt?sig=a%2Fb&part=1&part=2',
                  'default': false,
                },
              ],
            });
          }
          return FakeReply.text(200, page);
        }
        mediaRequests.add(request);
        expect(request.headers['User-Agent'], allohaUserAgent);
        expect(request.headers['Authorizations'], 'Bearer $guard');
        expect(request.headers['Accepts-Controls'], 'edge');
        if (request.uri.host == 'badcdn.example' &&
            request.uri.path == '/video-1080.m3u8') {
          if (failHighConnection) {
            throw DioException(
              requestOptions: request,
              type: DioExceptionType.connectionError,
            );
          }
          if (malformedHighPlaylist) {
            return const FakeReply.text(200, 'not a playlist');
          }
        }
        if (request.uri.host == 'badcdn.example' &&
            (!primaryAvailable ||
                request.uri.path == '/video-1080.m3u8' &&
                    !highPrimaryAvailable)) {
          return const FakeReply.text(403, '');
        }
        if (request.uri.host == 'cdn.example' &&
            request.uri.path == '/video-1080.m3u8' &&
            !highBackupAvailable) {
          return const FakeReply.text(403, '');
        }
        if (request.uri.path == '/video.m3u8' ||
            request.uri.path == '/video-1080.m3u8') {
          if (request.headers['Range'] != null || partialPlaylist) {
            return const FakeReply.text(
              206,
              '#EXTM3U\n#EXT-X',
              headers: {
                'content-range': ['bytes 0-13/69'],
              },
            );
          }
          return const FakeReply.text(
            200,
            '#EXTM3U\n#EXT-X-MAP:URI="init.mp4"\n#EXTINF:4,\nsegment.ts\n#EXT-X-ENDLIST\n',
          );
        }
        if (request.uri.path == '/full.vtt') {
          final query = request.uri.queryParametersAll;
          return failSubtitle ||
                  query['t']?.singleOrNull != guard ||
                  query['b']?.singleOrNull != expectedFingerprint ||
                  query['sig']?.singleOrNull != 'a/b' ||
                  query['part']?.join(',') != '1,2'
              ? const FakeReply.text(403, '')
              : const FakeReply.text(200, 'WEBVTT\n\n');
        }
        if (request.uri.path == '/segment.ts' && failFirstSegment) {
          failFirstSegment = false;
          return const FakeReply.text(403, '');
        }
        return const FakeReply.text(
          206,
          'segment',
          headers: {
            'content-range': ['bytes 0-6/10'],
          },
        );
      });
    Future<WebSocket> connect(Uri _, Map<String, dynamic> headers) {
      expect(headers['User-Agent'], allohaUserAgent);
      return WebSocket.connect('ws://127.0.0.1:${socketServer.port}');
    }

    final source = AllohaDataSource(dio: dio, connect: connect);
    final client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await source.close();
      for (final socket in sockets) {
        await socket.close();
      }
      await socketServer.close(force: true);
    });
    final links = await source.links(_player, videoId: 42);
    expect(dio.options.headers['User-Agent'], contains('Windows'));
    expect(links.single.quality, 720);
    expect(starts.map((start) => start['track_id']), everyElement('6'));
    expect(starts.map((start) => start['subtitle']), everyElement(-1));
    expect(starts, hasLength(2));
    Future<({int status, String text, String? contentRange})> fetch(
      String url, {
      String? range,
    }) async {
      final request = await client.getUrl(Uri.parse(url));
      if (range != null) request.headers.set('Range', range);
      final response = await request.close();
      return (
        status: response.statusCode,
        text: await utf8.decoder.bind(response).join(),
        contentRange: response.headers.value('content-range'),
      );
    }

    void expectMediaHosts(int start, String path, List<String> hosts) {
      expect(
        mediaRequests
            .skip(start)
            .where((request) => request.uri.path == path)
            .map((request) => request.uri.host),
        hosts,
      );
    }

    final subtitle = await fetch(links.single.subtitleUrl!);
    expect(subtitle.text, startsWith('WEBVTT'));
    expect(mediaRequests.last.uri.path, '/full.vtt');
    final playlist = await fetch(links.single.url);
    expect(playlist.text, contains('#EXTM3U'));
    final rangedPlaylist = await fetch(links.single.url, range: 'bytes=0-');
    expect(rangedPlaylist.status, 200);
    expect(rangedPlaylist.text, playlist.text);
    expect(rangedPlaylist.contentRange, isNull);
    expect(mediaRequests.last.headers['Range'], isNull);
    partialPlaylist = true;
    expect((await fetch(links.single.url)).status, 502);
    partialPlaylist = false;
    final lines = playlist.text.split('\n');
    expect(lines[1], contains('URI="../'));
    final startsBeforeSegment = starts.length;
    final segment = await fetch(
      Uri.parse(links.single.url).resolve(lines[3]).toString(),
      range: 'bytes=0-6',
    );
    expect(segment.status, 206);
    expect(segment.text, 'segment');
    expect(segment.contentRange, 'bytes 0-6/10');
    expect(mediaRequests.last.headers['Range'], 'bytes=0-6');
    expect(starts.length, startsBeforeSegment + 1);
    final reopened = await source.links(_player, videoId: 42);
    expect((await fetch(reopened.single.url)).text, playlist.text);

    useSeparateReserve = true;
    primaryAvailable = true;
    var since = mediaRequests.length;
    await source.links(_player, videoId: 42);
    expectMediaHosts(since, '/video.m3u8', ['badcdn.example']);
    reserveUrl = 'https://127.0.0.1/video.m3u8';
    await source.links(_player, videoId: 42);
    expect(mediaRequests.any((r) => r.uri.host == '127.0.0.1'), isFalse);

    primaryAvailable = false;
    reserveUrl = 'https://cdn.example/video.m3u8';
    since = mediaRequests.length;
    final reserved = await source.links(_player, videoId: 42);
    expectMediaHosts(since, '/video.m3u8', [
      'badcdn.example',
      'badcdn.example',
      'cdn.example',
    ]);
    expect((await fetch(reserved.single.url)).text, playlist.text);

    primaryAvailable = true;
    multiQuality = true;
    final qualityLinks = await source.links(_player, videoId: 42);
    var high = qualityLinks.singleWhere((link) => link.quality == 1080);
    since = mediaRequests.length;
    final highPlaylist = await fetch(high.url);
    expect(highPlaylist.status, 200);
    expectMediaHosts(since, '/video-1080.m3u8', [
      'badcdn.example',
      'badcdn.example',
      'cdn.example',
    ]);
    final highSegment = Uri.parse(
      high.url,
    ).resolve(highPlaylist.text.split('\n')[3]);
    expect((await fetch(highSegment.toString())).status, 206);
    expect(mediaRequests.last.uri.host, 'cdn.example');

    since = mediaRequests.length;
    expect((await fetch(high.url)).status, 200);
    expectMediaHosts(since, '/video-1080.m3u8', ['cdn.example']);

    highBackupAvailable = false;
    highPrimaryAvailable = true;
    since = mediaRequests.length;
    expect((await fetch(high.url)).status, 200);
    expectMediaHosts(since, '/video-1080.m3u8', [
      'cdn.example',
      'cdn.example',
      'badcdn.example',
    ]);
    highBackupAvailable = true;
    highPrimaryAvailable = false;

    malformedHighPlaylist = true;
    high = (await source.links(
      _player,
      videoId: 42,
    )).singleWhere((link) => link.quality == 1080);
    since = mediaRequests.length;
    expect((await fetch(high.url)).status, 200);
    expectMediaHosts(since, '/video-1080.m3u8', [
      'badcdn.example',
      'cdn.example',
    ]);
    malformedHighPlaylist = false;
    failHighConnection = true;
    high = (await source.links(
      _player,
      videoId: 42,
    )).singleWhere((link) => link.quality == 1080);
    since = mediaRequests.length;
    expect((await fetch(high.url)).status, 200);
    expectMediaHosts(since, '/video-1080.m3u8', [
      'badcdn.example',
      'cdn.example',
    ]);

    failSubtitle = true;
    await expectLater(
      source.links(_player, videoId: 42),
      throwsA(
        isA<RemoteResponseException>().having(
          (error) => error.message,
          'message',
          contains('Alloha subtitle refused (HTTP 403)'),
        ),
      ),
    );
    final local = Uri.parse(links.single.url);
    final missing = local.replace(
      pathSegments: [local.pathSegments[0], '999', local.pathSegments[2]],
    );
    expect((await fetch(missing.toString())).status, 404);
  });
}

class _LateSocket implements WebSocket {
  bool closed = false;

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
