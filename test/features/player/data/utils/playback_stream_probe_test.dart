import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/data/utils/playback_stream_probe.dart';

void main() {
  test(
    'fails quickly when the HTTP stream never sends a response body',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((request) {
        // Intentionally never complete the response to emulate a blocked stream.
      });

      final probe = HttpPlaybackStreamProbe(
        timeout: const Duration(milliseconds: 100),
      );

      final result = await probe.probe(
        'http://${server.address.host}:${server.port}/stream',
      );

      expect(result.statusCode, isNull);
      expect(result.error, isA<TimeoutException>());
    },
  );
}
