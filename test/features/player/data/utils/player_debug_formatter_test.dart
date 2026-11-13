import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/data/utils/player_debug_formatter.dart';

void main() {
  test('redacts long magnet links for safer diagnostics', () {
    final result = redactMagnet(
      'magnet:?xt=urn:btih:1234567890ABCDEF1234567890ABCDEF12345678&dn=test',
    );

    expect(result, isNot(contains('1234567890ABCDEF1234567890ABCDEF12345678')));
  });
}
