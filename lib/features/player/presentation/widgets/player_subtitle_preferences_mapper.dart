import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';
import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';

const subtitleLibassFontAssetPath = 'assets/fonts/NotoSansCJKjp-Regular.otf';
const subtitleLibassFontFamilyName = 'Noto Sans CJK JP';
const torrentPlayerBufferSizeBytes = 256 * 1024 * 1024;
const torrentPlayerBackBufferSizeBytes = 32 * 1024 * 1024;

class PlayerRenderingConfiguration {
  const PlayerRenderingConfiguration({
    required this.playerConfiguration,
    required this.subtitleViewConfiguration,
    required this.videoControllerConfiguration,
    required this.mpvProperties,
  });

  final PlayerConfiguration playerConfiguration;
  final SubtitleViewConfiguration subtitleViewConfiguration;
  final VideoControllerConfiguration videoControllerConfiguration;
  final Map<String, String> mpvProperties;
}

PlayerRenderingConfiguration buildPlayerRenderingConfiguration(
  SubtitlePreferences preferences,
  PlayerDecodingPreferences decodingPreferences, {
  TargetPlatform? platform,
}) {
  return PlayerRenderingConfiguration(
    playerConfiguration: PlayerConfiguration(
      bufferSize: torrentPlayerBufferSizeBytes,
      libass: preferences.libassEnabled,
      libassAndroidFont: subtitleLibassFontAssetPath,
      libassAndroidFontName: subtitleLibassFontFamilyName,
    ),
    subtitleViewConfiguration: buildSubtitleViewConfiguration(preferences),
    videoControllerConfiguration: buildVideoControllerConfiguration(
      decodingPreferences,
      platform: platform,
    ),
    mpvProperties: buildSubtitleMpvProperties(preferences),
  );
}

VideoControllerConfiguration buildVideoControllerConfiguration(
  PlayerDecodingPreferences preferences, {
  TargetPlatform? platform,
}) {
  final hwdecMode = resolveSupportedHwdecMode(
    preferences.hwdecMode,
    platform: platform,
  );
  return VideoControllerConfiguration(
    hwdec: _hwdecMode(hwdecMode),
    enableHardwareAcceleration: hwdecMode != PlayerHwdecModePreset.softwareOnly,
  );
}

/// Decoding presets that are valid for mpv on [platform].
///
/// `mediacodec` and `mediacodec-copy` exist only on Android.
List<PlayerHwdecModePreset> supportedHwdecModes({TargetPlatform? platform}) {
  if (_supportsMediacodec(platform)) {
    return PlayerHwdecModePreset.values;
  }
  return const [
    PlayerHwdecModePreset.autoSafe,
    PlayerHwdecModePreset.softwareOnly,
  ];
}

/// Maps a stored preset to one supported on [platform], falling back to the
/// `auto-safe` default when the preset is Android-only.
PlayerHwdecModePreset resolveSupportedHwdecMode(
  PlayerHwdecModePreset preset, {
  TargetPlatform? platform,
}) {
  if (supportedHwdecModes(platform: platform).contains(preset)) {
    return preset;
  }
  return const PlayerDecodingPreferences.defaults().hwdecMode;
}

bool _supportsMediacodec(TargetPlatform? platform) {
  return (platform ?? defaultTargetPlatform) == TargetPlatform.android;
}

SubtitleViewConfiguration buildSubtitleViewConfiguration(
  SubtitlePreferences preferences,
) {
  return SubtitleViewConfiguration(
    style: TextStyle(
      height: 1.4,
      fontSize: 32,
      color: subtitleTextColor(preferences.textColor),
      backgroundColor: _backgroundColor(preferences.backgroundStyle),
    ),
    textScaler: TextScaler.linear(_textScale(preferences.textScale)),
    padding: EdgeInsets.fromLTRB(
      16,
      0,
      16,
      _bottomPadding(preferences.verticalPosition),
    ),
  );
}

Map<String, String> buildSubtitleMpvProperties(
  SubtitlePreferences preferences,
) {
  return {
    'cache': 'yes',
    'cache-pause': 'yes',
    'cache-pause-initial': 'yes',
    'cache-pause-wait': '3',
    'cache-secs': '30',
    'demuxer-max-bytes': torrentPlayerBufferSizeBytes.toString(),
    'demuxer-max-back-bytes': torrentPlayerBackBufferSizeBytes.toString(),
    'demuxer-readahead-secs': '20',
    'network-timeout': '60',
    'vd-lavc-threads': '0',
    'sub-scale': _textScale(preferences.textScale).toString(),
    'sub-color': _mpvColor(subtitleTextColor(preferences.textColor)),
    'sub-back-color': _mpvColor(_backgroundColor(preferences.backgroundStyle)),
    'sub-pos': _subtitlePosition(preferences.verticalPosition).toString(),
    'sub-ass-override': overridesReleaseSubtitleStyle(preferences)
        ? 'force'
        : 'scale',
  };
}

bool requiresPlaybackRecreation({
  required SubtitlePreferences previousSubtitlePreferences,
  required SubtitlePreferences nextSubtitlePreferences,
  required PlayerDecodingPreferences previousDecodingPreferences,
  required PlayerDecodingPreferences nextDecodingPreferences,
  TargetPlatform? platform,
}) {
  return previousSubtitlePreferences.libassEnabled !=
          nextSubtitlePreferences.libassEnabled ||
      resolveSupportedHwdecMode(
            previousDecodingPreferences.hwdecMode,
            platform: platform,
          ) !=
          resolveSupportedHwdecMode(
            nextDecodingPreferences.hwdecMode,
            platform: platform,
          );
}

String _hwdecMode(PlayerHwdecModePreset preset) {
  return switch (preset) {
    PlayerHwdecModePreset.autoSafe => 'auto-safe',
    PlayerHwdecModePreset.mediacodec => 'mediacodec',
    PlayerHwdecModePreset.mediacodecCopy => 'mediacodec-copy',
    PlayerHwdecModePreset.softwareOnly => 'no',
  };
}

double _textScale(SubtitleTextScalePreset preset) {
  return switch (preset) {
    SubtitleTextScalePreset.compact => 0.85,
    SubtitleTextScalePreset.normal => 1.0,
    SubtitleTextScalePreset.large => 1.15,
    SubtitleTextScalePreset.xLarge => 1.30,
  };
}

/// The colour a preset paints subtitles in.
Color subtitleTextColor(SubtitleTextColorPreset preset) {
  return switch (preset) {
    SubtitleTextColorPreset.white => const Color(0xFFFFFFFF),
    SubtitleTextColorPreset.yellow => const Color(0xFFFFFF00),
    SubtitleTextColorPreset.cyan => const Color(0xFF7FDBFF),
  };
}

Color _backgroundColor(SubtitleBackgroundStylePreset preset) {
  return switch (preset) {
    SubtitleBackgroundStylePreset.none => const Color(0x00000000),
    SubtitleBackgroundStylePreset.translucent => const Color(0xAA000000),
    SubtitleBackgroundStylePreset.solid => const Color(0xDD000000),
  };
}

double _bottomPadding(SubtitleVerticalPositionPreset preset) {
  return switch (preset) {
    SubtitleVerticalPositionPreset.low => 12,
    SubtitleVerticalPositionPreset.standard => 24,
    SubtitleVerticalPositionPreset.high => 56,
  };
}

int _subtitlePosition(SubtitleVerticalPositionPreset preset) {
  return switch (preset) {
    SubtitleVerticalPositionPreset.low => 104,
    SubtitleVerticalPositionPreset.standard => 100,
    SubtitleVerticalPositionPreset.high => 92,
  };
}

/// Whether the look replaces a release's own styling: mpv then forces the
/// colour, background and position onto styled (ASS) subtitles too.
bool overridesReleaseSubtitleStyle(SubtitlePreferences preferences) {
  return preferences.textColor !=
          const SubtitlePreferences.defaults().textColor ||
      preferences.backgroundStyle !=
          const SubtitlePreferences.defaults().backgroundStyle ||
      preferences.verticalPosition !=
          const SubtitlePreferences.defaults().verticalPosition;
}

String _mpvColor(Color color) {
  final alpha = (color.a * 255)
      .round()
      .clamp(0, 255)
      .toRadixString(16)
      .padLeft(2, '0');
  final red = (color.r * 255)
      .round()
      .clamp(0, 255)
      .toRadixString(16)
      .padLeft(2, '0');
  final green = (color.g * 255)
      .round()
      .clamp(0, 255)
      .toRadixString(16)
      .padLeft(2, '0');
  final blue = (color.b * 255)
      .round()
      .clamp(0, 255)
      .toRadixString(16)
      .padLeft(2, '0');
  return '#${alpha.toUpperCase()}${red.toUpperCase()}${green.toUpperCase()}${blue.toUpperCase()}';
}
