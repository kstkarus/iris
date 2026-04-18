import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/domain/repositories/subtitle_preferences_repository.dart';

class SharedPreferencesSubtitlePreferencesRepository
    implements SubtitlePreferencesRepository {
  SharedPreferencesSubtitlePreferencesRepository(this._preferences);

  static const _storageKey = 'player.subtitle_preferences';

  final SharedPreferences _preferences;

  @override
  Future<SubtitlePreferences> loadPreferences() async {
    final rawValue = _preferences.getString(_storageKey);
    if (rawValue == null || rawValue.isEmpty) {
      return const SubtitlePreferences.defaults();
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is Map<String, Object?>) {
        return SubtitlePreferences.fromJson(decoded);
      }
      if (decoded is Map) {
        return SubtitlePreferences.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      return const SubtitlePreferences.defaults();
    }

    return const SubtitlePreferences.defaults();
  }

  @override
  Future<void> savePreferences(SubtitlePreferences preferences) {
    return _preferences.setString(
      _storageKey,
      jsonEncode(preferences.toJson()),
    );
  }
}
