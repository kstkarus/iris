import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/settings/domain/entities/app_settings.dart';
import 'package:iris/features/settings/presentation/cubit/app_settings_cubit.dart';

import '../../settings_test_doubles.dart';

void main() {
  test('starts with the saved state and skips an unchanged setting', () async {
    const settings = AppSettings(themeMode: AppThemePreference.dark);
    final repository = MemoryAppSettingsRepository(settings);
    final cubit = AppSettingsCubit(repository: repository);

    expect(cubit.state, settings);
    final emitted = expectLater(cubit.stream, emitsDone);
    await cubit.setThemeMode(AppThemePreference.dark);
    expect(repository.writes, isEmpty);
    await cubit.close();
    await emitted;
  });

  test(
    'applies rapid changes immediately and saves each snapshot in order',
    () async {
      final repository = MemoryAppSettingsRepository(const AppSettings());
      final firstWrite = Completer<void>();
      final unblockFirstWrite = Completer<void>();
      repository.onSave = (_) async {
        if (repository.writes.length == 1) {
          firstWrite.complete();
          await unblockFirstWrite.future;
        }
      };
      final cubit = AppSettingsCubit(repository: repository);
      addTearDown(cubit.close);

      final theme = cubit.setThemeMode(AppThemePreference.dark);
      final locale = cubit.setLocale(AppLocalePreference.russian);
      final audio = cubit.setDefaultAudioLanguage(
        DefaultAudioLanguage.japanese,
      );
      final subtitle = cubit.setDefaultSubtitleLanguage(
        DefaultSubtitleLanguage.off,
      );

      const first = AppSettings(themeMode: AppThemePreference.dark);
      final second = first.copyWith(locale: AppLocalePreference.russian);
      final third = second.copyWith(
        defaultAudioLanguage: DefaultAudioLanguage.japanese,
      );
      final last = third.copyWith(
        defaultSubtitleLanguage: DefaultSubtitleLanguage.off,
      );
      expect(cubit.state, last);
      await firstWrite.future;
      expect(repository.writes, [first]);

      unblockFirstWrite.complete();
      await Future.wait([theme, locale, audio, subtitle]);
      expect(repository.writes, [first, second, third, last]);
      expect(repository.load(), last);
    },
  );

  test(
    'keeps the optimistic state and continues after a write error',
    () async {
      final repository = MemoryAppSettingsRepository(const AppSettings());
      repository.onSave = (_) async {
        if (repository.writes.length == 1) {
          throw StateError('storage unavailable');
        }
      };
      final cubit = AppSettingsCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.setThemeMode(AppThemePreference.light);
      expect(cubit.state.themeMode, AppThemePreference.light);
      expect(repository.load(), const AppSettings());

      await cubit.setLocale(AppLocalePreference.english);
      expect(repository.load(), cubit.state);
    },
  );
}
