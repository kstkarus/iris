import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/player/data/utils/stored_json.dart';
import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/domain/repositories/subtitle_preferences_repository.dart';

class SharedPreferencesSubtitlePreferencesRepository
    implements SubtitlePreferencesRepository {
  SharedPreferencesSubtitlePreferencesRepository(this._preferences);

  static const _storageKey = 'player.subtitle_preferences';

  final SharedPreferences _preferences;

  @override
  Future<SubtitlePreferences> loadPreferences() async {
    return readStoredJson(
      _preferences,
      _storageKey,
      fromJson: SubtitlePreferences.fromJson,
      fallback: const SubtitlePreferences.defaults(),
    );
  }

  @override
  Future<void> savePreferences(SubtitlePreferences preferences) {
    return writeStoredJson(_preferences, _storageKey, preferences.toJson());
  }
}
