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
    expect(await receivedAgent.future, allohaUserAgent);
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

  test(
    'opens a protected HLS stream with Japanese audio and Russian subtitles',
    () async {
      final socketServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final sockets = <WebSocket>[];
      final starts = <Map<String, dynamic>>[];
      socketServer.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((message) {
          starts.add(jsonDecode(message as String) as Map<String, dynamic>);
          socket.add(
            jsonEncode({'type': 'config_update', 'edge_hash': 'edge'}),
          );
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
      final guard = 'x' * 220;
      final mediaRequests = <RequestOptions>[];
      var failFirstSegment = true;
      var failSubtitle = false;
      var partialPlaylist = false;
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
                matches(RegExp(r'^[a-f0-9]{64}\|lnhgpiacojefmkbd$')),
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
                      '720':
                          'https://badcdn.example/video.m3u8 or https://cdn.example/video.m3u8',
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
                    'src': 'https://cdn.example/full.vtt',
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
          if (request.uri.host == 'badcdn.example') {
            return const FakeReply.text(403, '');
          }
          if (request.uri.path == '/video.m3u8') {
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
            return failSubtitle
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
      final segment = await fetch(
        Uri.parse(links.single.url).resolve(lines[3]).toString(),
        range: 'bytes=0-6',
      );
      expect(segment.status, 206);
      expect(segment.text, 'segment');
      expect(segment.contentRange, 'bytes 0-6/10');
      expect(mediaRequests.last.headers['Range'], 'bytes=0-6');
      expect(starts.length, 3);
      final reopened = await source.links(_player, videoId: 42);
      expect((await fetch(reopened.single.url)).text, playlist.text);
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
    },
  );
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
