enum SubtitleTextScalePreset { compact, normal, large, xLarge }

enum SubtitleTextColorPreset { white, yellow, cyan }

enum SubtitleBackgroundStylePreset { none, translucent, solid }

enum SubtitleVerticalPositionPreset { low, standard, high }

class SubtitlePreferences {
  const SubtitlePreferences({
    required this.visible,
    required this.libassEnabled,
    required this.textScale,
    required this.textColor,
    required this.backgroundStyle,
    required this.verticalPosition,
  });

  const SubtitlePreferences.defaults()
    : visible = true,
      libassEnabled = true,
      textScale = SubtitleTextScalePreset.normal,
      textColor = SubtitleTextColorPreset.white,
      backgroundStyle = SubtitleBackgroundStylePreset.translucent,
      verticalPosition = SubtitleVerticalPositionPreset.standard;

  final bool visible;
  final bool libassEnabled;
  final SubtitleTextScalePreset textScale;
  final SubtitleTextColorPreset textColor;
  final SubtitleBackgroundStylePreset backgroundStyle;
  final SubtitleVerticalPositionPreset verticalPosition;

  SubtitlePreferences copyWith({
    bool? visible,
    bool? libassEnabled,
    SubtitleTextScalePreset? textScale,
    SubtitleTextColorPreset? textColor,
    SubtitleBackgroundStylePreset? backgroundStyle,
    SubtitleVerticalPositionPreset? verticalPosition,
  }) {
    return SubtitlePreferences(
      visible: visible ?? this.visible,
      libassEnabled: libassEnabled ?? this.libassEnabled,
      textScale: textScale ?? this.textScale,
      textColor: textColor ?? this.textColor,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      verticalPosition: verticalPosition ?? this.verticalPosition,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'visible': visible,
      'libassEnabled': libassEnabled,
      'textScale': textScale.name,
      'textColor': textColor.name,
      'backgroundStyle': backgroundStyle.name,
      'verticalPosition': verticalPosition.name,
    };
  }

  factory SubtitlePreferences.fromJson(Map<String, Object?> json) {
    return SubtitlePreferences(
      visible:
          json['visible'] as bool? ??
          const SubtitlePreferences.defaults().visible,
      libassEnabled:
          json['libassEnabled'] as bool? ??
          const SubtitlePreferences.defaults().libassEnabled,
      textScale: _parseEnum(
        SubtitleTextScalePreset.values,
        json['textScale'],
        const SubtitlePreferences.defaults().textScale,
      ),
      textColor: _parseEnum(
        SubtitleTextColorPreset.values,
        json['textColor'],
        const SubtitlePreferences.defaults().textColor,
      ),
      backgroundStyle: _parseEnum(
        SubtitleBackgroundStylePreset.values,
        json['backgroundStyle'],
        const SubtitlePreferences.defaults().backgroundStyle,
      ),
      verticalPosition: _parseEnum(
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
        other.visible == visible &&
        other.libassEnabled == libassEnabled &&
        other.textScale == textScale &&
        other.textColor == textColor &&
        other.backgroundStyle == backgroundStyle &&
        other.verticalPosition == verticalPosition;
  }

  @override
  int get hashCode => Object.hash(
    visible,
    libassEnabled,
    textScale,
    textColor,
    backgroundStyle,
    verticalPosition,
  );
}

T _parseEnum<T extends Enum>(List<T> values, Object? rawValue, T fallback) {
  final name = rawValue as String?;
  if (name == null) {
    return fallback;
  }

  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }

  return fallback;
}
