import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/utils/file_display_name.dart';

void main() {
  test('drops folders and the extension', () {
    expect(fileDisplayName('Death Note 15.mkv'), 'Death Note 15');
    expect(fileDisplayName(r'Season 1\[Group] Ep 02.mp4'), '[Group] Ep 02');
    expect(fileDisplayName('Show/ep.03.v2.m2ts'), 'ep.03.v2');
  });

  test('keeps names without a real extension', () {
    expect(fileDisplayName('Episode 1'), 'Episode 1');
    expect(fileDisplayName('.mkv'), '.mkv');
    // A number is not an extension: specials keep their half.
    expect(fileDisplayName('Frieren 12.5'), 'Frieren 12.5');
    expect(fileDisplayName('1.5'), '1.5');
  });
}
