import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';

abstract interface class PlayerDecodingPreferencesRepository {
  Future<PlayerDecodingPreferences> loadPreferences();

  Future<void> savePreferences(PlayerDecodingPreferences preferences);
}
