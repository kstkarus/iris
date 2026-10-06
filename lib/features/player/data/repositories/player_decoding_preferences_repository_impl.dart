import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';
import 'package:iris/features/player/domain/repositories/player_decoding_preferences_repository.dart';

class PlayerDecodingPreferencesRepositoryImpl
    implements PlayerDecodingPreferencesRepository {
  PlayerDecodingPreferencesRepositoryImpl(this._preferences);

  static const _storageKey = 'player.decoding_preferences';

  final SharedPreferences _preferences;

  @override
  Future<PlayerDecodingPreferences> loadPreferences() async {
    final rawValue = _preferences.getString(_storageKey);
    if (rawValue == null || rawValue.isEmpty) {
      return const PlayerDecodingPreferences.defaults();
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is Map<String, Object?>) {
        return PlayerDecodingPreferences.fromJson(decoded);
      }
      if (decoded is Map) {
        return PlayerDecodingPreferences.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      return const PlayerDecodingPreferences.defaults();
    }

    return const PlayerDecodingPreferences.defaults();
  }

  @override
  Future<void> savePreferences(PlayerDecodingPreferences preferences) {
    return _preferences.setString(
      _storageKey,
      jsonEncode(preferences.toJson()),
    );
  }
}
