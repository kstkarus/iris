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
      configuration.playerConfiguration.bufferSize,
      192 * 1024 * 1024,
    );
    expect(
      configuration.playerConfiguration.libassAndroidFont,
      subtitleLibassFontAssetPath,
    );
    expect(
      configuration.playerConfiguration.libassAndroidFontName,
      subtitleLibassFontFamilyName,
    );
    expect(configuration.mpvProperties['cache'], 'yes');
    expect(configuration.mpvProperties['cache-pause'], 'yes');
    expect(configuration.mpvProperties['cache-pause-initial'], 'yes');
    expect(configuration.mpvProperties['cache-pause-wait'], '2');
    expect(configuration.mpvProperties['demuxer-max-bytes'], '201326592');
    expect(configuration.mpvProperties['demuxer-max-back-bytes'], '33554432');
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
