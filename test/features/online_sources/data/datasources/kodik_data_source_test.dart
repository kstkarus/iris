import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/online_sources/data/datasources/kodik_data_source.dart';
import 'package:iris/features/online_sources/data/models/video_link_dto.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/video_server_dio_factory.dart';

/// Recorded from the live player (trimmed; CDN hosts replaced).
String _fixture(String name) =>
    File('test/fixtures/kodik/$name').readAsStringSync();

const _player =
    'https://kodikplayer.com/season/94795/d5a209e95d68094e346175d7357ef0c7/'
    '720p?translations=false&only_episode=true&episode=1';

void main() {
  late List<RequestOptions> requests;

  /// Answers like Kodik; [refusals] API answers are refused first, as when
  /// the API path moved.
  KodikDataSource source({
    String page = '',
    int refusals = 0,
    String apiPath = '/ftor',
  }) {
    final dio = createVideoServerDio();
    var refused = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final path = options.uri.path;
          Response<String> answer(int status, String body) =>
              Response(requestOptions: options, statusCode: status, data: body);
          if (path.startsWith('/season/')) {
            handler.resolve(
              answer(200, page.isEmpty ? _fixture('page.html') : page),
            );
          } else if (path.startsWith('/assets/js/')) {
            handler.resolve(answer(200, _fixture('player.js')));
          } else if (path == apiPath && refused++ >= refusals) {
            handler.resolve(answer(200, _fixture('api.json')));
          } else {
            handler.resolve(answer(404, 'Not Found'));
          }
        },
      ),
    );
    return KodikDataSource(dio: dio);
  }

  setUp(() => requests = []);

  test('reads the links the player page signs for, best first', () async {
    final links = await source().links(_player);

    expect([for (final l in links) l.quality], [720, 480, 360]);
    expect(links.every((l) => l.kind == VideoLinkKind.hls), isTrue);
    expect(
      links.first.url,
      'https://cdn.example.test/kodik/720.mp4:hls:manifest.m3u8',
    );

    final post = requests.last;
    expect(post.method, 'POST');
    expect(post.uri.toString(), 'https://kodikplayer.com/ftor');
    expect(post.headers['Origin'], 'https://kodikplayer.com');
    expect(post.headers['Referer'], _player);
    expect(post.data, {
      'd': 'kodikplayer.com',
      'd_sign':
          '0758a367801e7340d0979be2f2bc4598b3c080dfae7ac245850228c6f1e3eb57'
          ':2610110013',
      'pd': 'kodikplayer.com',
      'pd_sign':
          '0758a367801e7340d0979be2f2bc4598b3c080dfae7ac245850228c6f1e3eb57'
          ':2610110013',
      'ref': '',
      'ref_sign':
          'cfb484ca334734f6a697834650a8a83292490f5b1662d72038ec47aa9b18a28a'
          ':2610110013',
      'type': 'seria',
      'hash': 'd5a209e95d68094e346175d7357ef0c7',
      'id': '1211977',
      'bad_user': 'false',
      'info': '{}',
      'cdn_is_working': 'true',
    });
  });

  test('reads the API path once and reuses it', () async {
    final kodik = source();
    await kodik.links(_player);
    await kodik.links(_player);

    final scripts = requests.where(
      (request) => request.uri.path.startsWith('/assets/js/'),
    );
    expect(scripts, hasLength(1));
  });

  test('reads the API path again when the API refuses', () async {
    final links = await source(refusals: 1).links(_player);

    expect(links, isNotEmpty);
    final scripts = requests.where(
      (request) => request.uri.path.startsWith('/assets/js/'),
    );
    expect(scripts, hasLength(2));
  });

  test('a deleted video is not found', () {
    expect(
      source(
        page: '<div class="message">Episode not found</div>',
      ).links(_player),
      throwsA(isA<ResourceNotFoundException>()),
    );
  });

  test('fails when the API keeps refusing', () {
    expect(
      source(apiPath: '/elsewhere').links(_player),
      throwsA(isA<RemoteResponseException>()),
    );
  });

  test('swaps back the 480 file Kodik gives under its 720 key', () {
    final links = parseKodikLinks(
      '{"links":{"720":[{"src":"//cdn.example.test/a/480.mp4:hls:manifest.m3u8"}],'
      '"480":[{"src":"//cdn.example.test/a/480.mp4:hls:manifest.m3u8"}]}}',
    );

    expect(
      [for (final l in links) (l.quality, l.url)],
      [
        (720, 'https://cdn.example.test/a/720.mp4:hls:manifest.m3u8'),
        (480, 'https://cdn.example.test/a/480.mp4:hls:manifest.m3u8'),
      ],
    );
  });

  test('decodes hidden, plain and schemeless links', () {
    expect(
      decodeKodikLink('//cdn.example.test/a/720.mp4:hls:manifest.m3u8'),
      'https://cdn.example.test/a/720.mp4:hls:manifest.m3u8',
    );
    // The fixture hides its links as the live API does.
    final api = parseKodikLinks(_fixture('api.json'));
    expect(
      api.last.url,
      'https://cdn.example.test/kodik/360.mp4:hls:manifest.m3u8',
    );
  });
}
