import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';
import 'package:iris/features/player/domain/repositories/player_decoding_preferences_repository.dart';

class PlayerDecodingPreferencesCubit extends Cubit<PlayerDecodingPreferences> {
  PlayerDecodingPreferencesCubit({
    required PlayerDecodingPreferencesRepository repository,
  }) : _repository = repository,
       super(const PlayerDecodingPreferences.defaults());

  final PlayerDecodingPreferencesRepository _repository;

  Future<void> loadPreferences() async {
    final preferences = await _repository.loadPreferences();
    emit(preferences);
  }

  Future<void> setHwdecMode(PlayerHwdecModePreset preset) {
    return _save(state.copyWith(hwdecMode: preset));
  }

  Future<void> reset() {
    return _save(const PlayerDecodingPreferences.defaults());
  }

  Future<void> _save(PlayerDecodingPreferences preferences) async {
    emit(preferences);
    await _repository.savePreferences(preferences);
  }
}
