import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/app/app.dart';
import 'package:iris/app/bootstrap/create_app.dart';
import 'package:iris/app/di/service_locator.dart';
import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_track_preferences.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/models/anime_player_args.dart';
import 'package:iris/features/player/presentation/pages/player_page.dart';
import 'package:iris/features/settings/domain/entities/app_settings.dart';
import 'package:iris/features/settings/presentation/cubit/animejoy_account_cubit.dart';
import 'package:iris/features/settings/presentation/cubit/animejoy_account_state.dart';
import 'package:iris/features/settings/presentation/cubit/app_settings_cubit.dart';

import '../helpers/mock_app.dart';

void main() {
  tearDown(() => serviceLocator.reset());

  testWidgets(
    'applies saved appearance on the first frame and updates it live',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'settings.theme_mode': 'dark',
        'settings.locale': 'russian',
      });
      await tester.pumpWidget(await createApp(useMocks: true));

      MaterialApp materialApp() =>
          tester.widget<MaterialApp>(find.byType(MaterialApp));
      final router = materialApp().routerConfig;
      expect(materialApp().themeMode, ThemeMode.dark);
      expect(materialApp().locale, const Locale('ru'));

      final context = tester.element(find.byType(IrisApp));
      final account = context.read<AnimejoyAccountCubit>();
      expect(account.state, const AnimejoyAccountInitial());
      final settings = context.read<AppSettingsCubit>();
      await settings.setThemeMode(AppThemePreference.light);
      await settings.setLocale(AppLocalePreference.system);
      await tester.pump();

      expect(materialApp().themeMode, ThemeMode.light);
      expect(materialApp().locale, isNull);
      expect(materialApp().routerConfig, same(router));
    },
  );

  testWidgets(
    'keeps a locale override and passes current track defaults to torrents',
    (tester) async {
      SharedPreferences.setMockInitialValues({'settings.locale': 'russian'});
      await tester.pumpWidget(
        await createApp(useMocks: true, locale: const Locale('en')),
      );
      final settings = tester
          .element(find.byType(IrisApp))
          .read<AppSettingsCubit>();
      await settings.setLocale(AppLocalePreference.system);
      await settings.setDefaultAudioLanguage(DefaultAudioLanguage.japanese);
      await settings.setDefaultSubtitleLanguage(DefaultSubtitleLanguage.off);
      await tester.pump();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
        const Locale('en'),
      );

      final router = serviceLocator<GoRouter>();
      final player = find.byType(PlayerPage);
      Future<PlayerTrackPreferences?> openSource(String link) async {
        router.pushNamed<void>(
          'player',
          extra: AnimePlayerArgs(
            AnimePlayerSource(
              animeId: '5114',
              animeTitle: 'Fullmetal Alchemist',
              sourceTitle: 'Release',
              sessionId: 'mock-player',
              fileIndex: 0,
              fileName: 'Episode 1',
              magnet: link,
            ),
          ),
        );
        await pumpUntilVisible(tester, player);
        await tester.pumpAndSettle();
        return tester.element(player).read<PlayerCubit>().trackPreferences;
      }

      expect(
        await openSource(
          'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
        ),
        const PlayerTrackPreferences(
          audio: PreferredTrack(language: 'ja'),
          subtitle: PreferredTrack.off(),
        ),
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(await openSource('online:animejoy/1?anime=5114'), isNull);
    },
  );
}
