import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';

void main() {
  test('uses expected defaults', () {
    const preferences = SubtitlePreferences.defaults();

    expect(preferences.visible, isTrue);
    expect(preferences.libassEnabled, isTrue);
    expect(preferences.textScale, SubtitleTextScalePreset.normal);
    expect(preferences.textColor, SubtitleTextColorPreset.white);
    expect(
      preferences.backgroundStyle,
      SubtitleBackgroundStylePreset.translucent,
    );
    expect(
      preferences.verticalPosition,
      SubtitleVerticalPositionPreset.standard,
    );
  });

  test('serializes and restores preferences', () {
    const preferences = SubtitlePreferences(
      visible: false,
      libassEnabled: false,
      textScale: SubtitleTextScalePreset.large,
      textColor: SubtitleTextColorPreset.yellow,
      backgroundStyle: SubtitleBackgroundStylePreset.solid,
      verticalPosition: SubtitleVerticalPositionPreset.high,
    );

    final json = preferences.toJson();
    final restored = SubtitlePreferences.fromJson(json);

    expect(restored, preferences);
  });
}
