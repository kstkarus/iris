import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';
import 'package:iris/features/player/domain/repositories/player_decoding_preferences_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';

void main() {
  test('loads saved preferences from repository', () async {
    final repository = _FakePlayerDecodingPreferencesRepository(
      const PlayerDecodingPreferences(
        hwdecMode: PlayerHwdecModePreset.mediacodec,
      ),
    );
    final cubit = PlayerDecodingPreferencesCubit(repository: repository);

    await cubit.loadPreferences();

    expect(cubit.state.hwdecMode, PlayerHwdecModePreset.mediacodec);
  });

  test('persists updates immediately', () async {
    final repository = _FakePlayerDecodingPreferencesRepository(
      const PlayerDecodingPreferences.defaults(),
    );
    final cubit = PlayerDecodingPreferencesCubit(repository: repository);

    await cubit.setHwdecMode(PlayerHwdecModePreset.softwareOnly);

    expect(cubit.state.hwdecMode, PlayerHwdecModePreset.softwareOnly);
    expect(repository.savedStates, [
      const PlayerDecodingPreferences(
        hwdecMode: PlayerHwdecModePreset.softwareOnly,
      ),
    ]);
  });
}

class _FakePlayerDecodingPreferencesRepository
    implements PlayerDecodingPreferencesRepository {
  _FakePlayerDecodingPreferencesRepository(this.loadedState);

  PlayerDecodingPreferences loadedState;
  final List<PlayerDecodingPreferences> savedStates = [];

  @override
  Future<PlayerDecodingPreferences> loadPreferences() async {
    return loadedState;
  }

  @override
  Future<void> savePreferences(PlayerDecodingPreferences preferences) async {
    savedStates.add(preferences);
    loadedState = preferences;
  }
}
