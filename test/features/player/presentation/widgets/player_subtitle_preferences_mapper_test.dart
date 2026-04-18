import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/presentation/widgets/player_subtitle_preferences_mapper.dart';

void main() {
  test('builds subtitle view configuration from preferences', () {
    const preferences = SubtitlePreferences(
      visible: true,
      libassEnabled: true,
      textScale: SubtitleTextScalePreset.large,
      textColor: SubtitleTextColorPreset.yellow,
      backgroundStyle: SubtitleBackgroundStylePreset.solid,
      verticalPosition: SubtitleVerticalPositionPreset.high,
    );

    final configuration = buildSubtitleViewConfiguration(preferences);

    expect(configuration, isA<SubtitleViewConfiguration>());
    expect(configuration.visible, isTrue);
    expect(configuration.style.color, const Color(0xFFFFFF00));
    expect(configuration.style.backgroundColor, const Color(0xDD000000));
    expect(configuration.padding.bottom, 56);
  });

  test('builds player rendering configuration with bundled libass font', () {
    final configuration = buildPlayerRenderingConfiguration(
      const SubtitlePreferences.defaults(),
    );

    expect(configuration.playerConfiguration.libass, isTrue);
    expect(
      configuration.playerConfiguration.libassAndroidFont,
      subtitleLibassFontAssetPath,
    );
    expect(
      configuration.playerConfiguration.libassAndroidFontName,
      subtitleLibassFontFamilyName,
    );
  });

  test('recreates player only when libass toggle changes', () {
    const previous = SubtitlePreferences.defaults();

    expect(
      requiresPlaybackRecreation(
        previous,
        previous.copyWith(textColor: SubtitleTextColorPreset.cyan),
      ),
      isFalse,
    );

    expect(
      requiresPlaybackRecreation(
        previous,
        previous.copyWith(libassEnabled: false),
      ),
      isTrue,
    );
  });
}
