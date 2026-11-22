import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/settings/domain/entities/app_settings.dart';
import 'package:iris/features/settings/domain/repositories/app_settings_repository.dart';
import 'package:iris/shared/utils/serial_queue.dart';

final class AppSettingsCubit extends Cubit<AppSettings> {
  AppSettingsCubit({required AppSettingsRepository repository})
    : _repository = repository,
      super(repository.load());

  final AppSettingsRepository _repository;
  final _writes = SerialQueue();

  Future<void> setThemeMode(AppThemePreference themeMode) =>
      _save(state.copyWith(themeMode: themeMode));

  Future<void> setLocale(AppLocalePreference locale) =>
      _save(state.copyWith(locale: locale));

  Future<void> setAnimeTitleLanguage(AnimeTitleLanguage language) =>
      _save(state.copyWith(animeTitleLanguage: language));

  Future<void> setDefaultAudioLanguage(DefaultAudioLanguage language) =>
      _save(state.copyWith(defaultAudioLanguage: language));

  Future<void> setDefaultSubtitleLanguage(DefaultSubtitleLanguage language) =>
      _save(state.copyWith(defaultSubtitleLanguage: language));

  Future<void> _save(AppSettings settings) async {
    if (isClosed || settings == state) return;
    emit(settings);
    try {
      await _writes.run(() => _repository.save(settings));
    } on Object catch (error, stackTrace) {
      developer.log(
        'Unable to save app settings.',
        name: 'iris.settings',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
