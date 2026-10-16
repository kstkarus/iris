import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/data/adapters/hls_playlist.dart';

void main() {
  final base = Uri.parse(
    'https://cdn.example.test/video/720.mp4:hls:manifest.m3u8',
  );

  group('pickVariant', () {
    const master = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=854x480
480/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720
720/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080
https://other.example.test/1080/index.m3u8
''';

    test('takes the variant of the quality asked for', () {
      expect(
        HlsPlaylist.pickVariant(
          master,
          Uri.parse('https://cdn.example.test/master.m3u8'),
          quality: 720,
        ),
        (
          uri: Uri.parse('https://cdn.example.test/720/index.m3u8'),
          height: 720,
        ),
      );
    });

    test('takes the best variant when none is that high', () {
      expect(HlsPlaylist.pickVariant(master, base, quality: 2160), (
        uri: Uri.parse('https://other.example.test/1080/index.m3u8'),
        height: 1080,
      ));
    });

    test('gives nothing for a media playlist', () {
      expect(
        HlsPlaylist.pickVariant(
          '#EXTM3U\n#EXTINF:6,\na.ts\n',
          base,
          quality: 720,
        ),
        isNull,
      );
    });
  });

  group('parseMedia', () {
    test('reads segments with their play time, Kodik names included', () {
      const text =
          '#EXTM3U\r\n'
          '#EXT-X-TARGETDURATION:6\r\n'
          '#EXTINF:6.006,\r\n'
          './720.mp4:hls:seg-1-v1-a1.ts\r\n'
          '#EXTINF:4.5,\r\n'
          '720.mp4:hls:seg-2-v1-a1.ts\r\n'
          '#EXT-X-ENDLIST\r\n';

      final plan = HlsPlaylist.parseMedia(text, base)!;

      expect(plan.init, isNull);
      expect(plan.fragmentedMp4, isFalse);
      expect(
        [for (final segment in plan.segments) segment.uri.toString()],
        [
          'https://cdn.example.test/video/720.mp4:hls:seg-1-v1-a1.ts',
          'https://cdn.example.test/video/720.mp4:hls:seg-2-v1-a1.ts',
        ],
      );
      expect(
        [for (final segment in plan.segments) segment.seconds],
        [6.006, 4.5],
      );
    });

    test('keeps the init segment of fragmented MP4', () {
      const text =
          '#EXTM3U\n'
          '#EXT-X-MAP:URI="init.mp4"\n'
          '#EXTINF:4,\n'
          '//edge.example.test/seg1.m4s\n';

      final plan = HlsPlaylist.parseMedia(text, base)!;

      expect(
        plan.init?.uri,
        Uri.parse('https://cdn.example.test/video/init.mp4'),
      );
      expect(plan.fragmentedMp4, isTrue);
      expect(
        plan.segments.single.uri,
        Uri.parse('https://edge.example.test/seg1.m4s'),
      );
    });

    test('a plain key changes nothing', () {
      const text = '#EXTM3U\n#EXT-X-KEY:METHOD=NONE\n#EXTINF:4,\na.ts\n';

      expect(HlsPlaylist.parseMedia(text, base)?.segments, hasLength(1));
    });

    test('does not load encrypted, byte-range or empty playlists', () {
      for (final text in [
        '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n#EXTINF:4,\na.ts\n',
        '#EXTM3U\n#EXTINF:4,\n#EXT-X-BYTERANGE:1000@0\na.ts\n',
        '#EXTM3U\n#EXT-X-ENDLIST\n',
      ]) {
        expect(HlsPlaylist.parseMedia(text, base), isNull, reason: text);
      }
    });
  });
}
