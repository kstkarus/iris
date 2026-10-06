import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/torrent/torrent_activity_registry.dart';
import 'package:iris/shared/torrent/torrent_key.dart';

void main() {
  group('torrentKeyFromMagnet', () {
    test('uses the lower-case info-hash', () {
      expect(
        torrentKeyFromMagnet('magnet:?xt=urn:btih:ABCDEF1234&dn=Episode'),
        'abcdef1234',
      );
    });

    test('ignores display name and trackers', () {
      expect(
        torrentKeyFromMagnet('magnet:?xt=urn:btih:abc&tr=udp://a'),
        torrentKeyFromMagnet('magnet:?dn=x&xt=urn:btih:ABC'),
      );
    });

    test('falls back to a stable hash without btih', () {
      const magnet = 'magnet:?dn=only-a-name';
      expect(torrentKeyFromMagnet(magnet), torrentKeyFromMagnet(magnet));
      expect(torrentKeyFromMagnet(magnet), isNotEmpty);
    });
  });

  group('TorrentActivityRegistry', () {
    test('notifies synchronously on first acquire and last release', () {
      final registry = TorrentActivityRegistry();
      final events = <String>[];
      registry.streamingStarted.listen((key) => events.add('start:$key'));
      registry.streamingStopped.listen((key) => events.add('stop:$key'));

      registry.acquireStreaming('a');
      expect(events, ['start:a']);
      registry.acquireStreaming('a');
      registry.releaseStreaming('a');
      expect(registry.isStreaming('a'), isTrue);
      registry.releaseStreaming('a');

      expect(events, ['start:a', 'stop:a']);
      expect(registry.isStreaming('a'), isFalse);
    });

    test('ignores releasing an unknown torrent', () {
      final registry = TorrentActivityRegistry();
      final stopped = <String>[];
      registry.streamingStopped.listen(stopped.add);

      registry.releaseStreaming('missing');

      expect(stopped, isEmpty);
    });
  });
}
