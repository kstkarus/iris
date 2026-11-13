import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';

void main() {
  test('reads a record saved with the old Show subtitles switch', () {
    // Hiding subtitles is the Off track now; a stored "hidden" is dropped
    // so it cannot keep them hidden with no switch left to show them.
    final restored = SubtitlePreferences.fromJson({
      'visible': false,
      'textColor': 'yellow',
    });

    expect(
      restored,
      const SubtitlePreferences.defaults().copyWith(
        textColor: SubtitleTextColorPreset.yellow,
      ),
    );
    expect(restored.toJson(), isNot(contains('visible')));
  });
}
