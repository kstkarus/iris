import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/online_sources/domain/repositories/online_quality_preferences.dart';

class SharedPreferencesOnlineQualityPreferences
    implements OnlineQualityPreferences {
  SharedPreferencesOnlineQualityPreferences(this._preferences);

  static const _watchingKey = 'online.quality.watching';
  static const _downloadingKey = 'online.quality.downloading';

  final SharedPreferences _preferences;

  @override
  int? get watching => _read(_watchingKey);

  @override
  Future<void> setWatching(int? height) => _write(_watchingKey, height);

  @override
  int? get downloading => _read(_downloadingKey);

  @override
  Future<void> setDownloading(int? height) => _write(_downloadingKey, height);

  /// A stored value that is not a height reads as "Auto".
  int? _read(String key) {
    final value = _preferences.get(key);
    return value is int && value > 0 ? value : null;
  }

  Future<void> _write(String key, int? height) async {
    if (height == null) {
      await _preferences.remove(key);
    } else {
      await _preferences.setInt(key, height);
    }
  }
}
