import 'package:iris/features/player/domain/entities/player_track_preferences.dart';

abstract interface class PlayerTrackPreferencesRepository {
  Future<PlayerTrackPreferences?> load({required String torrentKey});

  Future<void> save({
    required String torrentKey,
    required PlayerTrackPreferences preferences,
  });
}
