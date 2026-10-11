import 'package:flutter_test/flutter_test.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';

import 'package:iris/shared/utils/playback_runtime_initializer.dart';

void main() {
  test('applies the session settings right after the engine starts', () async {
    final calls = <String>[];
    BtConfig? applied;

    await startTorrentEngine(
      init: () async => calls.add('init'),
      configureSession: (config) {
        calls.add('configure');
        applied = config;
      },
    );

    expect(calls, ['init', 'configure']);
    expect(applied, same(torrentSessionConfig));
  });

  test('session settings keep the streaming cache and IPv6', () {
    expect(torrentSessionConfig.cacheSize, 256 * 1024 * 1024);
    expect(torrentSessionConfig.readerReadAhead, 95);
    expect(torrentSessionConfig.preloadCache, 60);
    expect(torrentSessionConfig.responsiveMode, isTrue);
    expect(torrentSessionConfig.enableIpv6, isTrue);
  });
}
