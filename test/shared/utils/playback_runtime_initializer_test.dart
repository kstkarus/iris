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
    // The native bridge otherwise overrides the requested listen interfaces.
    expect(applied?.enableIpv6, isTrue);
  });
}
