import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/torrent/torrent_activity_registry.dart';

void main() {
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
