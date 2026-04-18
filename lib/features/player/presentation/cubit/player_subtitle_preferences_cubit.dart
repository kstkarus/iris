import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/domain/repositories/subtitle_preferences_repository.dart';

class PlayerSubtitlePreferencesCubit extends Cubit<SubtitlePreferences> {
  PlayerSubtitlePreferencesCubit({
    required SubtitlePreferencesRepository repository,
  }) : _repository = repository,
       super(const SubtitlePreferences.defaults());

  final SubtitlePreferencesRepository _repository;

  Future<void> loadPreferences() async {
    final preferences = await _repository.loadPreferences();
    emit(preferences);
  }

  Future<void> setVisibility(bool visible) {
    return _save(state.copyWith(visible: visible));
  }

  Future<void> setLibassEnabled(bool enabled) {
    return _save(state.copyWith(libassEnabled: enabled));
  }

  Future<void> setTextScale(SubtitleTextScalePreset preset) {
    return _save(state.copyWith(textScale: preset));
  }

  Future<void> setTextColor(SubtitleTextColorPreset preset) {
    return _save(state.copyWith(textColor: preset));
  }

  Future<void> setBackgroundStyle(SubtitleBackgroundStylePreset preset) {
    return _save(state.copyWith(backgroundStyle: preset));
  }

  Future<void> setVerticalPosition(SubtitleVerticalPositionPreset preset) {
    return _save(state.copyWith(verticalPosition: preset));
  }

  Future<void> reset() {
    return _save(const SubtitlePreferences.defaults());
  }

  Future<void> _save(SubtitlePreferences preferences) async {
    emit(preferences);
    await _repository.savePreferences(preferences);
  }
}
