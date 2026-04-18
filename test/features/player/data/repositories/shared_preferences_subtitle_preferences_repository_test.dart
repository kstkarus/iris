import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/player/data/repositories/shared_preferences_subtitle_preferences_repository.dart';
import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';

void main() {
  test('returns defaults when nothing was saved yet', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesSubtitlePreferencesRepository(
      preferences,
    );

    final result = await repository.loadPreferences();

    expect(result, const SubtitlePreferences.defaults());
  });

  test('persists and restores subtitle preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesSubtitlePreferencesRepository(
      preferences,
    );
    const saved = SubtitlePreferences(
      visible: false,
      libassEnabled: false,
      textScale: SubtitleTextScalePreset.compact,
      textColor: SubtitleTextColorPreset.cyan,
      backgroundStyle: SubtitleBackgroundStylePreset.none,
      verticalPosition: SubtitleVerticalPositionPreset.low,
    );

    await repository.savePreferences(saved);
    final restored = await repository.loadPreferences();

    expect(restored, saved);
  });
}
