import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/player/data/utils/stored_json.dart';
import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';
import 'package:iris/features/player/domain/repositories/player_decoding_preferences_repository.dart';

class PlayerDecodingPreferencesRepositoryImpl
    implements PlayerDecodingPreferencesRepository {
  PlayerDecodingPreferencesRepositoryImpl(this._preferences);

  static const _storageKey = 'player.decoding_preferences';

  final SharedPreferences _preferences;

  @override
  Future<PlayerDecodingPreferences> loadPreferences() async {
    return readStoredJson(
      _preferences,
      _storageKey,
      fromJson: PlayerDecodingPreferences.fromJson,
      fallback: const PlayerDecodingPreferences.defaults(),
    );
  }

  @override
  Future<void> savePreferences(PlayerDecodingPreferences preferences) {
    return writeStoredJson(_preferences, _storageKey, preferences.toJson());
  }
}
