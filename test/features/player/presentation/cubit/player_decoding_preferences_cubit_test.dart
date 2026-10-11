import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';

import '../../player_test_doubles.dart';

void main() {
  test('loads saved preferences from repository', () async {
    final repository = MemoryDecodingPreferencesRepository(
      const PlayerDecodingPreferences(
        hwdecMode: PlayerHwdecModePreset.mediacodec,
      ),
    );
    final cubit = PlayerDecodingPreferencesCubit(repository: repository);

    await cubit.loadPreferences();

    expect(cubit.state.hwdecMode, PlayerHwdecModePreset.mediacodec);
  });

  test('persists updates immediately', () async {
    final repository = MemoryDecodingPreferencesRepository(
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
