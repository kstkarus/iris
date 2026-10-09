import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_source_link.dart';

void main() {
  test('spells and reads back a release link', () {
    const link = OnlineSourceLink(
      provider: OnlineProvider.anilibria,
      releaseId: '9542',
    );

    expect(link.toString(), 'online:anilibria/9542');
    expect(OnlineSourceLink.tryParse('online:anilibria/9542'), link);
  });

  test('reads nothing from a magnet or a malformed link', () {
    for (final value in [
      'magnet:?xt=urn:btih:abc',
      'online:anilibria',
      'online:anilibria/',
      'online:unknown/1',
      'online:anilibria/1/2',
      '',
    ]) {
      expect(OnlineSourceLink.tryParse(value), isNull, reason: value);
    }
  });
}
