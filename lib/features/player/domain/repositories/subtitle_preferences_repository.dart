import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';

abstract interface class SubtitlePreferencesRepository {
  Future<SubtitlePreferences> loadPreferences();

  Future<void> savePreferences(SubtitlePreferences preferences);
}
