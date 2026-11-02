import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris/features/online_sources/data/datasources/alloha_stream_proxy.dart';

import '../../../../helpers/fake_http_adapter.dart';

void main() {
  late HttpServer socketServer;
  late List<WebSocket> sockets;
  late List<Uri> requests;
  late FakeReply Function(RequestOptions) respond;
  late Dio dio;
  late AllohaStreamProxy proxy;
  late HttpClient client;

  setUp(() async {
    socketServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    sockets = [];
    requests = [];
    socketServer.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {
        socket.add(jsonEncode({'type': 'config_update', 'edge_hash': 'edge'}));
      });
    });
    dio = Dio()
      ..httpClientAdapter = FakeHttpAdapter((request) {
        requests.add(request.uri);
        if (request.uri.path == '/sub.vtt') {
          return const FakeReply.text(200, 'WEBVTT\n\n');
        }
        return respond(request);
      });
    proxy = AllohaStreamProxy(
      dio: dio,
      connect: (_, _) =>
          WebSocket.connect('ws://127.0.0.1:${socketServer.port}'),
    );
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await proxy.close();
    dio.close(force: true);
    for (final socket in sockets) {
      await socket.close();
    }
    await socketServer.close(force: true);
  });

  Future<Uri> open({List<String>? mirrors}) async {
    final links = await proxy.open(
      player: Uri.parse('https://player.stravers.live/?token=test'),
      socket: Uri.parse('wss://player.stravers.live/socket'),
      socketId: 'test',
      guard: 'guard',
      audioId: '6',
      qualities: {
        720:
            (mirrors ??
                    [
                      'https://primary.example/master.m3u8',
                      'https://backup.example/other/master.m3u8',
                    ])
                .map(Uri.parse)
                .toList(),
      },
      subtitle: Uri.parse('https://primary.example/sub.vtt'),
    );
    return Uri.parse(links.qualities[720]!);
  }

  Future<({int status, String body})> fetch(Uri uri) async {
    final request = await client.getUrl(uri);
    final response = await request.close();
    return (
      status: response.statusCode,
      body: await utf8.decoder.bind(response).join(),
    );
  }

  test('tries the next mirror when reading a 200 playlist fails', () async {
    var primaryCount = 0;
    respond = (request) {
      if (request.uri.host == 'primary.example') {
        primaryCount++;
        if (primaryCount > 1) {
          return const FakeReply.text(
            200,
            '#EXTM3U\n',
            breakOff: SocketException('connection dropped'),
          );
        }
      }
      return const FakeReply.text(200, '#EXTM3U\n#EXT-X-ENDLIST\n');
    };

    final playlist = await open();
    requests.clear();
    final result = await fetch(playlist);
    expect(result.status, 200);
    expect(result.body, contains('#EXT-X-ENDLIST'));
    expect(requests.map((uri) => uri.host), [
      'primary.example',
      'backup.example',
    ]);

    requests.clear();
    expect((await fetch(playlist)).status, 200);
    expect(requests.map((uri) => uri.host), ['backup.example']);
  });

  test('reports a failed playlist when there is no usable mirror', () async {
    var primaryCount = 0;
    respond = (_) => ++primaryCount == 1
        ? const FakeReply.text(200, '#EXTM3U\n')
        : const FakeReply.text(
            200,
            '#EXTM3U\n',
            breakOff: SocketException('connection dropped'),
          );
    final playlist = await open(
      mirrors: ['https://primary.example/master.m3u8'],
    );
    expect((await fetch(playlist)).status, 502);
  });

  test('uses the matching nested playlist from the reserve parent', () async {
    respond = (request) {
      final uri = request.uri;
      if (uri.host == 'primary.example' && uri.path == '/master.m3u8') {
        return const FakeReply.text(
          200,
          '#EXTM3U\n'
          '#EXT-X-STREAM-INF:RESOLUTION=1280x720,BANDWIDTH=1100\n'
          'level/main.m3u8?token=primary\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=500,RESOLUTION=640x360\n'
          'level/low.m3u8\n',
        );
      }
      if (uri.host == 'backup.example' && uri.path == '/other/master.m3u8') {
        return const FakeReply.text(
          200,
          '#EXTM3U\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=500,RESOLUTION=640x360\n'
          '/different/low.m3u8\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=1000,RESOLUTION=1280x720\n'
          'https://backup.example/signed/video.m3u8?token=reserve%2F123\n',
        );
      }
      if (uri.host == 'primary.example' && uri.path == '/level/main.m3u8') {
        return const FakeReply.text(403, '');
      }
      if (uri.host == 'backup.example' && uri.path == '/signed/video.m3u8') {
        expect(uri.query, 'token=reserve%2F123');
        return const FakeReply.text(
          200,
          '#EXTM3U\n#EXTINF:4,\nsegment.ts\n#EXT-X-ENDLIST\n',
        );
      }
      if (uri.host == 'backup.example' && uri.path == '/signed/segment.ts') {
        return const FakeReply.text(200, 'segment');
      }
      return const FakeReply.text(404, '');
    };

    final playlist = await open();
    requests.clear();
    final master = await fetch(playlist);
    expect(master.status, 200);
    expect(requests.map((uri) => uri.host), ['primary.example']);
    final child = playlist.resolve(master.body.split('\n')[2]);

    requests.clear();
    final nested = await fetch(child);
    expect(nested.status, 200);
    expect(requests.map((uri) => '${uri.host}${uri.path}'), [
      'primary.example/level/main.m3u8',
      'primary.example/level/main.m3u8',
      'backup.example/other/master.m3u8',
      'backup.example/signed/video.m3u8',
    ]);
    expect(
      (await fetch(child.resolve(nested.body.split('\n')[2]))).body,
      'segment',
    );

    requests.clear();
    expect((await fetch(child)).status, 200);
    expect(requests.map((uri) => uri.host), ['backup.example']);
  });

  test('matches a nested playlist in a URI attribute', () async {
    respond = (request) {
      final uri = request.uri;
      if (uri.path.endsWith('/master.m3u8')) {
        final child = uri.host == 'primary.example'
            ? '/audio/main.m3u8'
            : '/different/audio.m3u8?signature=backup';
        return FakeReply.text(
          200,
          '#EXTM3U\n'
          '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="japanese",NAME="Original",URI="$child"\n',
        );
      }
      if (uri.host == 'primary.example') return const FakeReply.text(403, '');
      if (uri.path == '/different/audio.m3u8' &&
          uri.query == 'signature=backup') {
        return const FakeReply.text(200, '#EXTM3U\n#EXT-X-ENDLIST\n');
      }
      return const FakeReply.text(404, '');
    };

    final playlist = await open();
    final master = await fetch(playlist);
    final reference = RegExp(r'URI="([^"]+)"').firstMatch(master.body)![1]!;
    expect((await fetch(playlist.resolve(reference))).status, 200);
    expect(requests.any((uri) => uri.path == '/different/audio.m3u8'), isTrue);
  });

  test('follows parent mirrors through multiple playlist levels', () async {
    respond = (request) {
      final uri = request.uri;
      if (uri.host == 'primary.example' && uri.path == '/master.m3u8') {
        return const FakeReply.text(
          200,
          '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\n'
          '/chain/parent.m3u8\n',
        );
      }
      if (uri.host == 'primary.example' && uri.path == '/chain/parent.m3u8') {
        return const FakeReply.text(
          200,
          '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=200\nfinal.m3u8\n',
        );
      }
      if (uri.host == 'backup.example' && uri.path == '/other/master.m3u8') {
        return const FakeReply.text(
          200,
          '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\n'
          '/other/reserve-parent.m3u8\n',
        );
      }
      if (uri.host == 'backup.example' &&
          uri.path == '/other/reserve-parent.m3u8') {
        return const FakeReply.text(
          200,
          '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=200\n'
          '/other/final.m3u8?signature=reserve\n',
        );
      }
      if (uri.host == 'backup.example' &&
          uri.path == '/other/final.m3u8' &&
          uri.query == 'signature=reserve') {
        return const FakeReply.text(200, '#EXTM3U\n#EXT-X-ENDLIST\n');
      }
      return const FakeReply.text(403, '');
    };

    final root = await open();
    final rootPlaylist = await fetch(root);
    final parent = root.resolve(rootPlaylist.body.split('\n')[2]);
    final parentPlaylist = await fetch(parent);
    final child = parent.resolve(parentPlaylist.body.split('\n')[2]);
    expect(requests.any((uri) => uri.host == 'backup.example'), isFalse);

    requests.clear();
    expect((await fetch(child)).status, 200);
    expect(requests.map((uri) => '${uri.host}${uri.path}'), [
      'primary.example/chain/final.m3u8',
      'primary.example/chain/final.m3u8',
      'backup.example/other/master.m3u8',
      'backup.example/other/reserve-parent.m3u8',
      'backup.example/other/final.m3u8',
    ]);
  });

  test('returns to the primary parent if a reserve child fails', () async {
    var primaryMasters = 0;
    respond = (request) {
      final uri = request.uri;
      if (uri.host == 'primary.example' && uri.path == '/master.m3u8') {
        primaryMasters++;
        if (primaryMasters == 2 || primaryMasters == 3) {
          return const FakeReply.text(403, '');
        }
        return const FakeReply.text(
          200,
          '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\nprimary.m3u8\n',
        );
      }
      if (uri.host == 'backup.example' && uri.path == '/other/master.m3u8') {
        return const FakeReply.text(
          200,
          '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\nbackup.m3u8\n',
        );
      }
      if (uri.host == 'primary.example' && uri.path == '/primary.m3u8') {
        return const FakeReply.text(200, '#EXTM3U\n#EXT-X-ENDLIST\n');
      }
      return const FakeReply.text(403, '');
    };

    final root = await open();
    final master = await fetch(root);
    expect(master.status, 200);
    final child = root.resolve(master.body.split('\n')[2]);
    requests.clear();
    expect((await fetch(child)).status, 200);
    expect(requests.map((uri) => '${uri.host}${uri.path}'), [
      'backup.example/other/backup.m3u8',
      'backup.example/other/backup.m3u8',
      'primary.example/master.m3u8',
      'primary.example/primary.m3u8',
    ]);
  });

  test('tries nested mirrors one at a time until one succeeds', () async {
    respond = (request) {
      final uri = request.uri;
      if (uri.path == '/master.m3u8') {
        if (uri.host == 'backup.example') {
          return const FakeReply.text(
            200,
            '#EXTM3U\n',
            breakOff: SocketException('connection dropped'),
          );
        }
        return const FakeReply.text(
          200,
          '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\nchild.m3u8\n',
        );
      }
      if (uri.host == 'backup3.example') {
        return const FakeReply.text(200, '#EXTM3U\n#EXT-X-ENDLIST\n');
      }
      return const FakeReply.text(403, '');
    };

    final root = await open(
      mirrors: [
        'https://primary.example/master.m3u8',
        'https://backup.example/master.m3u8',
        'https://backup2.example/master.m3u8',
        'https://backup3.example/master.m3u8',
        'https://backup4.example/master.m3u8',
      ],
    );
    final master = await fetch(root);
    final child = root.resolve(master.body.split('\n')[2]);
    requests.clear();
    expect((await fetch(child)).status, 200);
    expect(requests.map((uri) => '${uri.host}${uri.path}'), [
      'primary.example/child.m3u8',
      'primary.example/child.m3u8',
      'backup.example/master.m3u8',
      'backup2.example/master.m3u8',
      'backup2.example/child.m3u8',
      'backup2.example/child.m3u8',
      'backup3.example/master.m3u8',
      'backup3.example/child.m3u8',
    ]);
  });

  test(
    'does not substitute a different or untrusted nested playlist',
    () async {
      var unsafe = false;
      var ambiguous = false;
      respond = (request) {
        final uri = request.uri;
        if (uri.host == 'primary.example' && uri.path == '/master.m3u8') {
          return const FakeReply.text(
            200,
            '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\nchild.m3u8\n',
          );
        }
        if (uri.host == 'backup.example' && uri.path == '/other/master.m3u8') {
          return FakeReply.text(
            200,
            ambiguous
                ? '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\n'
                      'child-a.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=1000\n'
                      'child-b.m3u8\n'
                : unsafe
                ? '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\n'
                      'https://untrusted.example/child.m3u8\n'
                : '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=500\n'
                      'wrong-quality.m3u8\n',
          );
        }
        return const FakeReply.text(403, '');
      };

      final playlist = await open();
      final master = await fetch(playlist);
      final child = playlist.resolve(master.body.split('\n')[2]);
      requests.clear();
      expect((await fetch(child)).status, 403);
      expect(requests.any((uri) => uri.path == '/other/master.m3u8'), isTrue);
      expect(
        requests.any((uri) => uri.path == '/other/wrong-quality.m3u8'),
        isFalse,
      );

      unsafe = true;
      requests.clear();
      expect((await fetch(child)).status, 403);
      expect(requests.any((uri) => uri.host == 'untrusted.example'), isFalse);

      ambiguous = true;
      requests.clear();
      expect((await fetch(child)).status, 403);
      expect(
        requests.any((uri) => uri.path.endsWith('/child-a.m3u8')),
        isFalse,
      );
      expect(
        requests.any((uri) => uri.path.endsWith('/child-b.m3u8')),
        isFalse,
      );
    },
  );
}
