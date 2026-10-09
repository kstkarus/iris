import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';
import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/presentation/widgets/player_subtitle_preferences_mapper.dart';

void main() {
  test('builds subtitle view configuration from preferences', () {
    const preferences = SubtitlePreferences(
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
      const PlayerDecodingPreferences.defaults(),
    );

    expect(configuration.playerConfiguration.libass, isTrue);
    expect(configuration.playerConfiguration.bufferSize, 256 * 1024 * 1024);
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
    expect(configuration.mpvProperties['cache-pause-wait'], '3');
    expect(configuration.mpvProperties['demuxer-max-bytes'], '268435456');
    expect(configuration.mpvProperties['demuxer-max-back-bytes'], '33554432');
    expect(configuration.mpvProperties['cache-secs'], '30');
    expect(configuration.mpvProperties['demuxer-readahead-secs'], '20');
    expect(configuration.mpvProperties['network-timeout'], '60');
    expect(configuration.mpvProperties['vd-lavc-threads'], '0');
    expect(configuration.mpvProperties, isNot(contains('hwdec')));
    expect(configuration.mpvProperties, isNot(contains('vd')));
    expect(configuration.mpvProperties, isNot(contains('hr-seek')));
    expect(
      configuration.videoControllerConfiguration.enableHardwareAcceleration,
      isTrue,
    );
    expect(configuration.videoControllerConfiguration.hwdec, 'auto-safe');
  });

  test('builds video controller configuration from decoding preferences', () {
    final softwareOnly = buildVideoControllerConfiguration(
      const PlayerDecodingPreferences(
        hwdecMode: PlayerHwdecModePreset.softwareOnly,
      ),
    );
    final mediacodecCopy = buildVideoControllerConfiguration(
      const PlayerDecodingPreferences(
        hwdecMode: PlayerHwdecModePreset.mediacodecCopy,
      ),
    );

    expect(softwareOnly.hwdec, 'no');
    expect(softwareOnly.enableHardwareAcceleration, isFalse);
    expect(mediacodecCopy.hwdec, 'mediacodec-copy');
    expect(mediacodecCopy.enableHardwareAcceleration, isTrue);
  });

  test('recreates player only when native rendering preference changes', () {
    const previous = SubtitlePreferences.defaults();
    const decoding = PlayerDecodingPreferences.defaults();

    expect(
      requiresPlaybackRecreation(
        previousSubtitlePreferences: previous,
        nextSubtitlePreferences: previous.copyWith(
          textColor: SubtitleTextColorPreset.cyan,
        ),
        previousDecodingPreferences: decoding,
        nextDecodingPreferences: decoding,
      ),
      isFalse,
    );

    expect(
      requiresPlaybackRecreation(
        previousSubtitlePreferences: previous,
        nextSubtitlePreferences: previous.copyWith(libassEnabled: false),
        previousDecodingPreferences: decoding,
        nextDecodingPreferences: decoding,
      ),
      isTrue,
    );

    expect(
      requiresPlaybackRecreation(
        previousSubtitlePreferences: previous,
        nextSubtitlePreferences: previous,
        previousDecodingPreferences: decoding,
        nextDecodingPreferences: decoding.copyWith(
          hwdecMode: PlayerHwdecModePreset.softwareOnly,
        ),
      ),
      isTrue,
    );
  });

  test('maps Android-only mediacodec presets to auto-safe on desktop', () {
    for (final preset in [
      PlayerHwdecModePreset.mediacodec,
      PlayerHwdecModePreset.mediacodecCopy,
    ]) {
      final configuration = buildVideoControllerConfiguration(
        PlayerDecodingPreferences(hwdecMode: preset),
        platform: TargetPlatform.windows,
      );

      expect(configuration.hwdec, 'auto-safe');
      expect(configuration.enableHardwareAcceleration, isTrue);
    }

    final rendering = buildPlayerRenderingConfiguration(
      const SubtitlePreferences.defaults(),
      const PlayerDecodingPreferences(
        hwdecMode: PlayerHwdecModePreset.mediacodec,
      ),
      platform: TargetPlatform.linux,
    );
    expect(rendering.videoControllerConfiguration.hwdec, 'auto-safe');
  });

  test('keeps mediacodec presets on Android', () {
    final configuration = buildVideoControllerConfiguration(
      const PlayerDecodingPreferences(
        hwdecMode: PlayerHwdecModePreset.mediacodec,
      ),
      platform: TargetPlatform.android,
    );

    expect(configuration.hwdec, 'mediacodec');
  });

  test('keeps software-only decoding on desktop', () {
    final configuration = buildVideoControllerConfiguration(
      const PlayerDecodingPreferences(
        hwdecMode: PlayerHwdecModePreset.softwareOnly,
      ),
      platform: TargetPlatform.windows,
    );

    expect(configuration.hwdec, 'no');
    expect(configuration.enableHardwareAcceleration, isFalse);
  });

  test('lists supported decoder presets per platform', () {
    expect(
      supportedHwdecModes(platform: TargetPlatform.android),
      PlayerHwdecModePreset.values,
    );
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.iOS,
    ]) {
      expect(supportedHwdecModes(platform: platform), const [
        PlayerHwdecModePreset.autoSafe,
        PlayerHwdecModePreset.softwareOnly,
      ]);
    }
  });

  test(
    'does not recreate the player when the effective hwdec is unchanged',
    () {
      const subtitles = SubtitlePreferences.defaults();

      expect(
        requiresPlaybackRecreation(
          previousSubtitlePreferences: subtitles,
          nextSubtitlePreferences: subtitles,
          previousDecodingPreferences: const PlayerDecodingPreferences(
            hwdecMode: PlayerHwdecModePreset.mediacodec,
          ),
          nextDecodingPreferences: const PlayerDecodingPreferences.defaults(),
          platform: TargetPlatform.windows,
        ),
        isFalse,
      );
      expect(
        requiresPlaybackRecreation(
          previousSubtitlePreferences: subtitles,
          nextSubtitlePreferences: subtitles,
          previousDecodingPreferences: const PlayerDecodingPreferences(
            hwdecMode: PlayerHwdecModePreset.mediacodec,
          ),
          nextDecodingPreferences: const PlayerDecodingPreferences.defaults(),
          platform: TargetPlatform.android,
        ),
        isTrue,
      );
    },
  );
}
