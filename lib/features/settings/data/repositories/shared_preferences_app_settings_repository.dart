import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/settings/domain/entities/app_settings.dart';
import 'package:iris/features/settings/domain/repositories/app_settings_repository.dart';
import 'package:iris/shared/utils/enum_by_name.dart';
import 'package:iris/shared/utils/json_read.dart';

final class SharedPreferencesAppSettingsRepository
    implements AppSettingsRepository {
  const SharedPreferencesAppSettingsRepository(this._preferences);

  static const _themeModeKey = 'settings.theme_mode';
  static const _localeKey = 'settings.locale';
  static const _animeTitleLanguageKey = 'settings.anime_title_language';
  static const _episodeListLayoutKey = 'settings.episode_list_layout';
  static const _audioKey = 'settings.default_audio_language';
  static const _subtitleKey = 'settings.default_subtitle_language';

  final SharedPreferences _preferences;

  @override
  AppSettings load() => AppSettings(
    themeMode: enumByName(
      AppThemePreference.values,
      jsonString(_preferences.get(_themeModeKey)),
      AppThemePreference.system,
    ),
    locale: enumByName(
      AppLocalePreference.values,
      jsonString(_preferences.get(_localeKey)),
      AppLocalePreference.system,
    ),
    animeTitleLanguage: enumByName(
      AnimeTitleLanguage.values,
      jsonString(_preferences.get(_animeTitleLanguageKey)),
      AnimeTitleLanguage.auto,
    ),
    episodeListLayout: enumByName(
      EpisodeListLayout.values,
      jsonString(_preferences.get(_episodeListLayoutKey)),
      EpisodeListLayout.auto,
    ),
    defaultAudioLanguage: enumByName(
      DefaultAudioLanguage.values,
      jsonString(_preferences.get(_audioKey)),
      DefaultAudioLanguage.auto,
    ),
    defaultSubtitleLanguage: enumByName(
      DefaultSubtitleLanguage.values,
      jsonString(_preferences.get(_subtitleKey)),
      DefaultSubtitleLanguage.auto,
    ),
  );

  @override
  Future<void> save(AppSettings settings) async {
    final saved = await Future.wait([
      _preferences.setString(_themeModeKey, settings.themeMode.name),
      _preferences.setString(_localeKey, settings.locale.name),
      _preferences.setString(
        _animeTitleLanguageKey,
        settings.animeTitleLanguage.name,
      ),
      _preferences.setString(
        _episodeListLayoutKey,
        settings.episodeListLayout.name,
      ),
      _preferences.setString(_audioKey, settings.defaultAudioLanguage.name),
      _preferences.setString(
        _subtitleKey,
        settings.defaultSubtitleLanguage.name,
      ),
    ]);
    if (saved.contains(false)) throw StateError('Unable to save app settings.');
  }
}
