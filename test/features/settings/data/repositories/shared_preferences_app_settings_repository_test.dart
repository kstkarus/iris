import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/settings/data/repositories/shared_preferences_app_settings_repository.dart';
import 'package:iris/features/settings/domain/entities/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing preferences load the defaults synchronously', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesAppSettingsRepository(
      await SharedPreferences.getInstance(),
    );

    expect(repository.load(), const AppSettings());
  });

  test('unknown and mistyped values fall back independently', () async {
    SharedPreferences.setMockInitialValues({
      'settings.theme_mode': 'future-theme',
      'settings.locale': 'russian',
      'settings.default_audio_language': 42,
      'settings.default_subtitle_language': ['english'],
    });
    final repository = SharedPreferencesAppSettingsRepository(
      await SharedPreferences.getInstance(),
    );

    expect(
      repository.load(),
      const AppSettings(locale: AppLocalePreference.russian),
    );
  });

  test('writes enum names that can be read back from storage', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesAppSettingsRepository(preferences);
    const settings = AppSettings(
      themeMode: AppThemePreference.dark,
      locale: AppLocalePreference.english,
      defaultAudioLanguage: DefaultAudioLanguage.japanese,
      defaultSubtitleLanguage: DefaultSubtitleLanguage.off,
    );

    await repository.save(settings);
    await preferences.reload();

    expect(preferences.getString('settings.theme_mode'), 'dark');
    expect(preferences.getString('settings.locale'), 'english');
    expect(
      preferences.getString('settings.default_audio_language'),
      'japanese',
    );
    expect(preferences.getString('settings.default_subtitle_language'), 'off');
    expect(repository.load(), settings);
  });
}
