import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/online_sources/data/datasources/aksor_data_source.dart';
import 'package:iris/features/online_sources/data/models/video_link_dto.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/video_server_dio_factory.dart';

import '../../../../helpers/fake_http_adapter.dart';

void main() {
  late List<RequestOptions> requests;

  AksorDataSource source({int status = 200}) {
    final dio = createVideoServerDio()
      ..httpClientAdapter = FakeHttpAdapter((options) {
        requests.add(options);
        return FakeReply.text(status, readFixture('aksor/video.json'));
      });
    return AksorDataSource(dio: dio);
  }

  setUp(() => requests = []);

  test('asks the API for the video the player page names', () async {
    final links = await source().links(
      'https://player.aksor.tv/video/36c45284528fe5b4f30a39d9f008d1b8',
    );

    expect(
      requests.single.uri.toString(),
      'https://player.aksor.tv/api/video/36c45284528fe5b4f30a39d9f008d1b8',
    );
    expect(requests.single.headers['Referer'], 'https://old.yummyani.me/');
    expect(links, hasLength(1));
    expect(links.single.quality, 1080);
    expect(links.single.kind, VideoLinkKind.dash);
    expect(
      links.single.url,
      'https://cdn.example.test/static13/video/a10661/AniLibria/01/1080.mpd',
    );
  });

  test('a video Aksor does not have is not found', () {
    expect(
      source(status: 404).links('https://player.aksor.tv/video/gone'),
      throwsA(isA<ResourceNotFoundException>()),
    );
  });

  test('keeps the qualities it can play, best first', () {
    final links = parseAksorLinks(
      '{"qualities":{"q360":"https://x.test/360.mp4",'
      '"q1080":"https://x.test/1080.m3u8","q720":null,'
      '"q4k":"https://x.test/4k.webm"}}',
    );

    expect(
      [for (final l in links) (l.quality, l.kind)],
      [(1080, VideoLinkKind.hls), (360, VideoLinkKind.mp4)],
    );
  });
}
