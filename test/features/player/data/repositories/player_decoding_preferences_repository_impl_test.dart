import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/player/data/repositories/player_decoding_preferences_repository_impl.dart';
import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';

void main() {
  test('returns defaults when nothing was saved yet', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = PlayerDecodingPreferencesRepositoryImpl(preferences);

    final result = await repository.loadPreferences();

    expect(result, const PlayerDecodingPreferences.defaults());
  });

  test('persists and restores every hwdec mode', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = PlayerDecodingPreferencesRepositoryImpl(preferences);

    for (final mode in PlayerHwdecModePreset.values) {
      final saved = PlayerDecodingPreferences(hwdecMode: mode);

      await repository.savePreferences(saved);
      final restored = await repository.loadPreferences();

      expect(restored, saved);
    }
  });
}
