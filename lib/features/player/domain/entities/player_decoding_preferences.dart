enum PlayerHwdecModePreset {
  autoSafe,
  mediacodec,
  mediacodecCopy,
  softwareOnly,
}

class PlayerDecodingPreferences {
  const PlayerDecodingPreferences({required this.hwdecMode});

  const PlayerDecodingPreferences.defaults()
    : hwdecMode = PlayerHwdecModePreset.autoSafe;

  final PlayerHwdecModePreset hwdecMode;

  PlayerDecodingPreferences copyWith({PlayerHwdecModePreset? hwdecMode}) {
    return PlayerDecodingPreferences(hwdecMode: hwdecMode ?? this.hwdecMode);
  }

  Map<String, Object?> toJson() {
    return {'hwdecMode': hwdecMode.name};
  }

  factory PlayerDecodingPreferences.fromJson(Map<String, Object?> json) {
    return PlayerDecodingPreferences(
      hwdecMode: _parseEnum(
        PlayerHwdecModePreset.values,
        json['hwdecMode'],
        const PlayerDecodingPreferences.defaults().hwdecMode,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerDecodingPreferences && other.hwdecMode == hwdecMode;
  }

  @override
  int get hashCode => hwdecMode.hashCode;
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
