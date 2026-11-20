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

    test(
      'takes the closest lower variant when the selected height is missing',
      () {
        expect(
          HlsPlaylist.pickVariant(master, base, quality: 600)?.height,
          480,
        );
      },
    );

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

    test('skips variants that require a separate audio playlist', () {
      const splitAudioMaster = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud-ext",NAME="Japanese",DEFAULT=YES,URI="audio.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080,AUDIO="aud-ext"
1080/video.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720
720/muxed.m3u8
''';

      expect(HlsPlaylist.pickVariant(splitAudioMaster, base, quality: 1080), (
        uri: Uri.parse('https://cdn.example.test/video/720/muxed.m3u8'),
        height: 720,
      ));
    });

    test('returns null when every variant requires a separate audio track', () {
      const splitAudioOnly = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="Japanese",URI="audio.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720,AUDIO="aud"
720/video.m3u8
''';

      expect(
        HlsPlaylist.pickVariant(splitAudioOnly, base, quality: 720),
        isNull,
      );
    });

    test('accepts variants whose audio group is muxed without a URI', () {
      const muxedAudioMaster = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="Japanese",DEFAULT=YES
#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720,AUDIO="aud"
720/muxed.m3u8
''';

      expect(HlsPlaylist.pickVariant(muxedAudioMaster, base, quality: 720), (
        uri: Uri.parse('https://cdn.example.test/video/720/muxed.m3u8'),
        height: 720,
      ));
    });
  });

  group('parseMedia', () {
    test('different variant heights identify different partial files', () {
      const text = '#EXTM3U\n#EXTINF:6,\na.ts\n#EXT-X-ENDLIST\n';
      final lower = HlsPlaylist.parseMedia(text, base, variantHeight: 480)!;
      final higher = HlsPlaylist.parseMedia(text, base, variantHeight: 720)!;

      expect(lower.fingerprint, isNot(higher.fingerprint));
    });

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
          '//edge.example.test/seg1.m4s\n'
          '#EXT-X-ENDLIST\n';

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
      const text =
          '#EXTM3U\n#EXT-X-KEY:METHOD=NONE\n#EXTINF:4,\na.ts\n#EXT-X-ENDLIST\n';

      expect(HlsPlaylist.parseMedia(text, base)?.segments, hasLength(1));
    });

    test('does not load master, encrypted or byte-range playlists', () {
      for (final text in [
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\n720.m3u8\n',
        '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n#EXTINF:4,\na.ts\n',
        '#EXTM3U\n#EXTINF:4,\n#EXT-X-BYTERANGE:1000@0\na.ts\n',
      ]) {
        expect(HlsPlaylist.parseMedia(text, base), isNull, reason: text);
      }
    });

    test('reports incomplete and non-playlist responses as malformed', () {
      for (final text in [
        '#EXTM3U\n#EXT-X-PLAYLIST-TYPE:EVENT\n#EXTINF:6,\na.ts\n',
        '#EXTM3U\n#EXTINF:6,\na.ts\n#EXTINF:6,\n',
        '#EXTM3U\n#EXT-X-ENDLIST\n',
        '<html>Sign in to watch</html>',
        '#EXTINF:6,\na.ts\n#EXT-X-ENDLIST\n',
      ]) {
        expect(() => HlsPlaylist.parseMedia(text, base), throwsFormatException);
      }
    });
  });
}
