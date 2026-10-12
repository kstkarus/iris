import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/online_sources/domain/entities/online_stream.dart';
import 'package:iris/features/online_sources/domain/online_stream_choice.dart';

OnlineStream _stream(
  int quality, {
  OnlineStreamFormat format = OnlineStreamFormat.hls,
  String player = 'kodik',
}) => OnlineStream(
  url: 'https://$player.test/$quality.${format.name}',
  quality: quality,
  format: format,
);

void main() {
  // yummy_anime asks the better player first: Aksor (DASH), then Kodik.
  final yummy = [
    _stream(1080, format: OnlineStreamFormat.dash, player: 'aksor'),
    _stream(720, format: OnlineStreamFormat.dash, player: 'aksor'),
    _stream(720),
    _stream(480),
    _stream(360),
  ];

  group('chooseOnlineStream', () {
    test('Auto plays the tallest, from the better player', () {
      expect(chooseOnlineStream(yummy)?.url, 'https://aksor.test/1080.dash');
    });

    test('plays the tallest at or below the choice', () {
      expect(
        chooseOnlineStream(yummy, maxQuality: 720)?.url,
        'https://aksor.test/720.dash',
      );
      expect(
        chooseOnlineStream(yummy, maxQuality: 600)?.url,
        'https://kodik.test/480.hls',
      );
    });

    test('takes the least tall above a choice nothing reaches down to', () {
      expect(chooseOnlineStream(yummy, maxQuality: 240)?.quality, 360);
    });

    test('loading leaves DASH out and takes an mp4 before HLS', () {
      expect(
        chooseOnlineStream(yummy, downloadable: true)?.url,
        'https://kodik.test/720.hls',
      );
      expect(
        chooseOnlineStream([
          _stream(720),
          _stream(720, format: OnlineStreamFormat.mp4),
        ], downloadable: true)?.format,
        OnlineStreamFormat.mp4,
      );
    });

    test('gives nothing when no stream fits', () {
      expect(chooseOnlineStream(const []), isNull);
      expect(
        chooseOnlineStream([
          _stream(1080, format: OnlineStreamFormat.dash),
        ], downloadable: true),
        isNull,
      );
    });
  });

  test('onlineQualities lists each height once, tallest first', () {
    expect(onlineQualities(yummy), [1080, 720, 480, 360]);
    expect(onlineQualities(yummy, downloadable: true), [720, 480, 360]);
  });

  test('closestQuality', () {
    expect(closestQuality(const [], 720), isNull);
    expect(closestQuality(const [1080, 720, 480], null), 1080);
    expect(closestQuality(const [1080, 720, 480], 720), 720);
    expect(closestQuality(const [1080, 480], 720), 480);
    expect(closestQuality(const [1080, 720], 360), 720);
  });
}
