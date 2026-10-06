import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/utils/release_title.dart';

void main() {
  test('drops the release details after the title', () {
    expect(
      releaseDisplayTitle(
        'Тетрадь смерти / Death Note [S01] (2006) BDRip-HEVC 1080p | '
        'СВ-дубль, Mega-Anime',
      ),
      'Тетрадь смерти / Death Note',
    );
  });

  test('drops the group tags before the title', () {
    expect(
      releaseDisplayTitle('[SubsPlease] Sousou no Frieren (1080p) [A1B2]'),
      'Sousou no Frieren',
    );
  });

  test('keeps a plain name and a name made of tags only', () {
    expect(releaseDisplayTitle('Cowboy Bebop'), 'Cowboy Bebop');
    expect(releaseDisplayTitle('[Batch] [1080p]'), '[Batch] [1080p]');
  });
}
