import 'package:iris/shared/utils/enum_by_name.dart';

enum SubtitleTextScalePreset { compact, normal, large, xLarge }

enum SubtitleTextColorPreset { white, yellow, cyan }

enum SubtitleBackgroundStylePreset { none, translucent, solid }

enum SubtitleVerticalPositionPreset { low, standard, high }

class SubtitlePreferences {
  const SubtitlePreferences({
    required this.libassEnabled,
    required this.textScale,
    required this.textColor,
    required this.backgroundStyle,
    required this.verticalPosition,
  });

  const SubtitlePreferences.defaults()
    : libassEnabled = true,
      textScale = SubtitleTextScalePreset.normal,
      textColor = SubtitleTextColorPreset.white,
      backgroundStyle = SubtitleBackgroundStylePreset.translucent,
      verticalPosition = SubtitleVerticalPositionPreset.standard;

  final bool libassEnabled;
  final SubtitleTextScalePreset textScale;
  final SubtitleTextColorPreset textColor;
  final SubtitleBackgroundStylePreset backgroundStyle;
  final SubtitleVerticalPositionPreset verticalPosition;

  SubtitlePreferences copyWith({
    bool? libassEnabled,
    SubtitleTextScalePreset? textScale,
    SubtitleTextColorPreset? textColor,
    SubtitleBackgroundStylePreset? backgroundStyle,
    SubtitleVerticalPositionPreset? verticalPosition,
  }) {
    return SubtitlePreferences(
      libassEnabled: libassEnabled ?? this.libassEnabled,
      textScale: textScale ?? this.textScale,
      textColor: textColor ?? this.textColor,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      verticalPosition: verticalPosition ?? this.verticalPosition,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'libassEnabled': libassEnabled,
      'textScale': textScale.name,
      'textColor': textColor.name,
      'backgroundStyle': backgroundStyle.name,
      'verticalPosition': verticalPosition.name,
    };
  }

  factory SubtitlePreferences.fromJson(Map<String, Object?> json) {
    return SubtitlePreferences(
      libassEnabled:
          json['libassEnabled'] as bool? ??
          const SubtitlePreferences.defaults().libassEnabled,
      textScale: enumByName(
        SubtitleTextScalePreset.values,
        json['textScale'],
        const SubtitlePreferences.defaults().textScale,
      ),
      textColor: enumByName(
        SubtitleTextColorPreset.values,
        json['textColor'],
        const SubtitlePreferences.defaults().textColor,
      ),
      backgroundStyle: enumByName(
        SubtitleBackgroundStylePreset.values,
        json['backgroundStyle'],
        const SubtitlePreferences.defaults().backgroundStyle,
      ),
      verticalPosition: enumByName(
        SubtitleVerticalPositionPreset.values,
        json['verticalPosition'],
        const SubtitlePreferences.defaults().verticalPosition,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is SubtitlePreferences &&
        other.libassEnabled == libassEnabled &&
        other.textScale == textScale &&
        other.textColor == textColor &&
        other.backgroundStyle == backgroundStyle &&
        other.verticalPosition == verticalPosition;
  }

  @override
  int get hashCode => Object.hash(
    libassEnabled,
    textScale,
    textColor,
    backgroundStyle,
    verticalPosition,
  );
}
