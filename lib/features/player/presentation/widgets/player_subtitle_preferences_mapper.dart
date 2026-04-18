import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';

const subtitleLibassFontAssetPath = 'assets/fonts/NotoSansCJKjp-Regular.otf';
const subtitleLibassFontFamilyName = 'Noto Sans CJK JP';

class PlayerRenderingConfiguration {
  const PlayerRenderingConfiguration({
    required this.playerConfiguration,
    required this.subtitleViewConfiguration,
    required this.mpvProperties,
  });

  final PlayerConfiguration playerConfiguration;
  final SubtitleViewConfiguration subtitleViewConfiguration;
  final Map<String, String> mpvProperties;
}

PlayerRenderingConfiguration buildPlayerRenderingConfiguration(
  SubtitlePreferences preferences,
) {
  return PlayerRenderingConfiguration(
    playerConfiguration: PlayerConfiguration(
      libass: preferences.libassEnabled,
      libassAndroidFont: subtitleLibassFontAssetPath,
      libassAndroidFontName: subtitleLibassFontFamilyName,
    ),
    subtitleViewConfiguration: buildSubtitleViewConfiguration(preferences),
    mpvProperties: buildSubtitleMpvProperties(preferences),
  );
}

SubtitleViewConfiguration buildSubtitleViewConfiguration(
  SubtitlePreferences preferences,
) {
  return SubtitleViewConfiguration(
    visible: preferences.visible,
    style: TextStyle(
      height: 1.4,
      fontSize: 32,
      color: _textColor(preferences.textColor),
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
    'sub-visibility': preferences.visible ? 'yes' : 'no',
    'sub-scale': _textScale(preferences.textScale).toString(),
    'sub-color': _mpvColor(_textColor(preferences.textColor)),
    'sub-back-color': _mpvColor(_backgroundColor(preferences.backgroundStyle)),
    'sub-pos': _subtitlePosition(preferences.verticalPosition).toString(),
    'sub-ass-override': _requiresAssForceOverride(preferences)
        ? 'force'
        : 'scale',
  };
}

bool requiresPlaybackRecreation(
  SubtitlePreferences previous,
  SubtitlePreferences next,
) {
  return previous.libassEnabled != next.libassEnabled;
}

double _textScale(SubtitleTextScalePreset preset) {
  return switch (preset) {
    SubtitleTextScalePreset.compact => 0.85,
    SubtitleTextScalePreset.normal => 1.0,
    SubtitleTextScalePreset.large => 1.15,
    SubtitleTextScalePreset.xLarge => 1.30,
  };
}

Color _textColor(SubtitleTextColorPreset preset) {
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

bool _requiresAssForceOverride(SubtitlePreferences preferences) {
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
