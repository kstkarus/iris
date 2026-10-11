import 'package:iris/shared/utils/enum_by_name.dart';

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
      hwdecMode: enumByName(
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
