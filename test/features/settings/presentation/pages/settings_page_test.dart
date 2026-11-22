import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

import 'package:iris/app/theme/app_theme.dart';
import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_version.dart';
import 'package:iris/features/app_update/domain/repositories/app_update_download_repository.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:iris/features/app_update/presentation/widgets/update_notice.dart';
import 'package:iris/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:iris/features/online_sources/domain/repositories/animejoy_account_repository.dart';
import 'package:iris/features/settings/domain/entities/app_settings.dart';
import 'package:iris/features/settings/presentation/cubit/animejoy_account_cubit.dart';
import 'package:iris/features/settings/presentation/cubit/app_settings_cubit.dart';
import 'package:iris/features/settings/presentation/pages/settings_page.dart';
import 'package:iris/features/settings/presentation/widgets/about_app_section.dart';
import 'package:iris/features/settings/presentation/widgets/animejoy_account_section.dart';
import 'package:iris/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:iris/features/settings/presentation/widgets/shikimori_account_row.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/widgets/pixel_noise.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/status_views.dart';

import '../../../../helpers/record_haptics.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';
import '../../../app_update/app_update_test_doubles.dart';
import '../../../auth/presentation/auth_test_doubles.dart';
import '../../settings_test_doubles.dart';

const _audio = Key('settings_default_audio_choice');
const _subtitles = Key('settings_default_subtitles_choice');
const _theme = Key('settings_theme_choice');
const _language = Key('settings_language_choice');
const _animeTitles = Key('settings_anime_title_language_choice');

void main() {
  Future<AppSettingsCubit> pumpSettings(
    WidgetTester tester, {
    Size size = TestWindowSizes.phone,
    Locale locale = const Locale('en'),
    double textScale = 1.0,
    FakeAuthRepository? authRepo,
    FakeAnimejoyAccountRepository? animejoyRepo,
    FakeAppUpdateRepository? updateRepo,
    Future<bool> Function(Uri url)? onOpenExternalUrl,
    bool asDialog = false,
    AppUpdateDownloadRepository? updateDownloads,
    TargetPlatform? platform,
  }) async {
    setTestWindowSize(tester, size);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final settingsRepo = MemoryAppSettingsRepository(const AppSettings());
    final settingsCubit = AppSettingsCubit(repository: settingsRepo);
    final authCubit = AuthCubit(repository: authRepo ?? FakeAuthRepository());
    await authCubit.restore();
    final accountRepo = animejoyRepo ?? FakeAnimejoyAccountRepository();
    final animejoyCubit = AnimejoyAccountCubit(repository: accountRepo);
    final appUpdateRepo =
        updateRepo ??
        FakeAppUpdateRepository(installed: const AppVersion(1, 5, 1));
    final updateCubit = AppUpdateCubit(
      repository: appUpdateRepo,
      downloads: updateDownloads,
    );

    addTearDown(() async {
      await settingsCubit.close();
      await authCubit.close();
      await animejoyCubit.close();
      await updateCubit.close();
      await accountRepo.changes.close();
    });

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: authCubit),
          BlocProvider.value(value: settingsCubit),
          BlocProvider.value(value: animejoyCubit),
          BlocProvider.value(value: updateCubit),
        ],
        child: testApp(
          asDialog
              ? Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showSettingsDialog(context),
                      child: const Text('Open settings'),
                    ),
                  ),
                )
              : SettingsPage(openExternalUrl: onOpenExternalUrl),
          locale: locale,
          theme: buildAppTheme(
            brightness: Brightness.dark,
          ).copyWith(platform: platform),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (asDialog) {
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
    }

    return settingsCubit;
  }

  Future<void> chooseFromMenu(
    WidgetTester tester,
    Key key,
    String label,
  ) async {
    final row = find.byKey(key);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, label));
    await tester.pumpAndSettle();
  }

  for (final (label, size, locale, textScale) in const [
    ('phone', TestWindowSizes.phone, Locale('en'), 1.0),
    ('narrow 320dp Russian', Size(320, 700), Locale('ru'), 1.0),
    ('narrow 320dp Russian 1.6x text', Size(320, 700), Locale('ru'), 1.6),
    ('desktop', Size(1280, 800), Locale('en'), 1.0),
  ]) {
    testWidgets('all 4 sections render without overflow on $label', (
      tester,
    ) async {
      await pumpSettings(
        tester,
        size: size,
        locale: locale,
        textScale: textScale,
      );

      final isRu = locale.languageCode == 'ru';
      final headings = isRu
          ? ['Аккаунты', 'Воспроизведение', 'Оформление', 'О приложении']
          : ['Accounts', 'Playback', 'Appearance', 'About'];
      var previousTop = 0.0;
      for (final label in headings) {
        final heading = find.text(label);
        expect(heading, findsOneWidget);
        final top = tester.getTopLeft(heading).dy;
        expect(top, greaterThan(previousTop));
        previousTop = top;
      }
      expect(find.text('1.5.1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('changing theme and language preferences updates settings', (
    tester,
  ) async {
    final settings = await pumpSettings(tester, size: const Size(1280, 800));

    Future<void> tapOption(Key groupKey, String label) async {
      final target = find.descendant(
        of: find.byKey(groupKey),
        matching: find.text(label),
      );
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await chooseFromMenu(tester, _audio, 'Japanese');
    expect(settings.state.defaultAudioLanguage, DefaultAudioLanguage.japanese);

    await chooseFromMenu(tester, _subtitles, 'Off');
    expect(settings.state.defaultSubtitleLanguage, DefaultSubtitleLanguage.off);

    await tapOption(_theme, 'Dark');
    expect(settings.state.themeMode, AppThemePreference.dark);

    await tapOption(_language, 'Русский');
    expect(settings.state.locale, AppLocalePreference.russian);

    expect(
      find.descendant(
        of: find.byKey(_animeTitles),
        matching: find.text('App language'),
      ),
      findsOneWidget,
    );
    await chooseFromMenu(tester, _animeTitles, 'Romaji');
    expect(settings.state.animeTitleLanguage, AnimeTitleLanguage.romaji);
    expect(settings.state.locale, AppLocalePreference.russian);
    expect(
      find.descendant(
        of: find.byKey(_animeTitles),
        matching: find.text('Romaji'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('AnimeJoy login works with the keyboard and 200% text', (
    tester,
  ) async {
    final repo = FakeAnimejoyAccountRepository();
    await pumpSettings(
      tester,
      size: const Size(320, 580),
      textScale: 2,
      animejoyRepo: repo,
    );
    final signIn = find.byKey(AnimejoyAccountSection.signInButtonKey);
    await tester.ensureVisible(signIn);
    await tester.pumpAndSettle();
    await tester.tap(signIn);
    await tester.pumpAndSettle();

    final login = find.byKey(AnimejoyAccountSection.loginFieldKey);
    final password = find.byKey(AnimejoyAccountSection.passwordFieldKey);
    await tester.ensureVisible(login);
    await tester.enterText(login, 'user');
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    final passwordInput = find.descendant(
      of: password,
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(passwordInput).focusNode.hasFocus, true);
    tester.testTextInput.enterText('secret');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repo.credentials, [('user', 'secret')]);
    expect(find.text('Connected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appearance options stay reachable at 320dp and 200% text', (
    tester,
  ) async {
    final settings = await pumpSettings(
      tester,
      size: const Size(320, 700),
      locale: const Locale('ru'),
      textScale: 2,
    );
    await chooseFromMenu(tester, _theme, 'Тёмная');
    expect(settings.state.themeMode, AppThemePreference.dark);
    await chooseFromMenu(tester, _language, 'English');
    expect(settings.state.locale, AppLocalePreference.english);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a keyboard can open, dismiss and reopen a playback menu', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      size: const Size(1280, 800),
      authRepo: FakeAuthRepository(canSignIn: false),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final option = find.widgetWithText(MenuItemButton, 'Japanese');
    expect(option, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(option, findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(option, findsOneWidget);
  });

  testWidgets('Accounts signs out of Shikimori and can sign in again', (
    tester,
  ) async {
    final auth = FakeAuthRepository(restored: testAccount)
      ..signInGate = Completer<void>();
    await pumpSettings(tester, authRepo: auth);
    expect(find.text('kstk'), findsOneWidget);
    await tester.tap(find.byKey(ShikimoriAccountRow.signOutButtonKey));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 1);
    expect(
      find.descendant(
        of: find.byType(ShikimoriAccountRow),
        matching: find.text('Not connected'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AnimejoyAccountSection),
        matching: find.text('Not connected'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(ShikimoriAccountRow.signInButtonKey));
    await tester.pump();
    final status = find.text('Signing in');
    expect(status.hitTestable(), findsOneWidget);
    expect(
      tester.getTopLeft(status).dx,
      tester.getTopLeft(find.text('Shikimori')).dx,
    );
    auth.signInGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('kstk'), findsOneWidget);
  });

  testWidgets(
    'AnimeJoy sign-in handles validation, failure, success and sign-out',
    (tester) async {
      final effects = recordHaptics();
      final repo = FakeAnimejoyAccountRepository()
        ..signInSession = () async => throw const AnimejoySignInRejected();
      await pumpSettings(tester, animejoyRepo: repo);

      final signIn = find.byKey(AnimejoyAccountSection.signInButtonKey);
      await tester.tap(signIn);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Sign in to AnimeJoy'), findsOneWidget);
      expect(find.text('Use your animejoy.ru account'), findsNothing);
      expect(
        tester.getSemantics(find.byKey(AnimejoyAccountSection.loginFieldKey)),
        isSemantics(label: 'Username', isTextField: true),
      );
      expect(
        tester.getSemantics(
          find.byKey(AnimejoyAccountSection.passwordFieldKey),
        ),
        isSemantics(label: 'Password', isTextField: true, isObscured: true),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(signIn.hitTestable(), findsOneWidget);
      expect(repo.credentials, isEmpty);
      expect(effects, isEmpty);

      await tester.tap(signIn);
      await tester.pumpAndSettle();

      // Empty fields show inline validation without submitting.
      await tester.tap(find.byKey(AnimejoyAccountSection.submitButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('Enter username'), findsOneWidget);
      expect(find.text('Enter password'), findsOneWidget);
      expect(repo.credentials, isEmpty);
      expect(effects, [HapticsType.error]);

      // Invalid credentials keep the sheet open and show the error.
      await tester.enterText(
        find.byKey(AnimejoyAccountSection.loginFieldKey),
        'user',
      );
      await tester.enterText(
        find.byKey(AnimejoyAccountSection.passwordFieldKey),
        'wrong',
      );
      await tester.tap(find.byKey(AnimejoyAccountSection.submitButtonKey));
      await tester.pumpAndSettle();
      expect(repo.credentials, [('user', 'wrong')]);
      expect(find.byKey(AnimejoyAccountSection.signInSheetKey), findsOneWidget);
      expect(find.text('Wrong username or password'), findsOneWidget);
      expect(effects, [HapticsType.error, HapticsType.error]);

      // Valid credentials sign in and close the sheet.
      repo.signInSession = null;
      await tester.enterText(
        find.byKey(AnimejoyAccountSection.passwordFieldKey),
        'secret',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byKey(AnimejoyAccountSection.signInSheetKey), findsNothing);
      expect(find.text('Connected'), findsOneWidget);
      expect(
        find.byKey(AnimejoyAccountSection.signOutButtonKey),
        findsOneWidget,
      );

      // Signing out returns to the signed-out state.
      await tester.tap(find.byKey(AnimejoyAccountSection.signOutButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('Connected'), findsNothing);
      expect(
        find.byKey(AnimejoyAccountSection.signInButtonKey),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(effects, [
        HapticsType.error,
        HapticsType.error,
        HapticsType.success,
      ]);
    },
  );

  testWidgets('desktop AnimeJoy sign-in stays in the Settings dialog', (
    tester,
  ) async {
    final repo = FakeAnimejoyAccountRepository();
    await pumpSettings(
      tester,
      size: const Size(1280, 800),
      animejoyRepo: repo,
      asDialog: true,
    );

    final dialog = find.byType(Dialog);
    final settingsRoute = ModalRoute.of(tester.element(dialog));
    final signIn = find.byKey(AnimejoyAccountSection.signInButtonKey);
    final login = find.byKey(AnimejoyAccountSection.loginFieldKey);

    Future<void> openForm() async {
      await tester.tap(signIn);
      await tester.pump();
      expect(find.text('Accounts'), findsOneWidget);
      expect(signIn.hitTestable(), findsNothing);
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);
      expect(ModalRoute.of(tester.element(login)), same(settingsRoute));
      expect(find.text('Sign in to AnimeJoy'), findsOneWidget);
      expect(find.text('Accounts'), findsNothing);
    }

    await openForm();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(signIn.hitTestable(), findsOneWidget);

    await openForm();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(signIn.hitTestable(), findsOneWidget);
    expect(repo.credentials, isEmpty);

    await openForm();
    await tester.enterText(login, 'user');
    await tester.enterText(
      find.byKey(AnimejoyAccountSection.passwordFieldKey),
      'secret',
    );
    final pending = Completer<void>();
    repo.signInSession = () => pending.future;
    final submit = find.byKey(AnimejoyAccountSection.submitButtonKey);
    final idle = tester.getRect(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(
      find.descendant(of: submit, matching: find.text('Signing in')),
      findsOneWidget,
    );
    expect(tester.getRect(submit), idle);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    pending.complete();
    await tester.pumpAndSettle();

    expect(repo.credentials, [('user', 'secret')]);
    expect(dialog, findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(login, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unverified AnimeJoy session shows Verify and recovers when online',
    (tester) async {
      final repo = FakeAnimejoyAccountRepository()
        ..saved = true
        ..restoreSession = () async =>
            throw const NetworkRequestException('offline');
      await pumpSettings(
        tester,
        size: const Size(320, 700),
        textScale: 2,
        animejoyRepo: repo,
      );

      expect(find.text('Couldn’t verify session'), findsOneWidget);
      expect(find.text('No response. Check your connection.'), findsOneWidget);
      expect(
        find.byKey(AnimejoyAccountSection.verifyButtonKey),
        findsOneWidget,
      );

      final pending = Completer<bool>();
      repo.restoreSession = () => pending.future;
      final verify = find.byKey(AnimejoyAccountSection.verifyButtonKey);
      await tester.ensureVisible(verify);
      await tester.pumpAndSettle();
      await tester.tap(verify);
      await tester.pump();
      expect(find.text('Checking session'), findsOneWidget);
      pending.complete(true);
      await tester.pumpAndSettle();

      expect(find.text('Connected'), findsOneWidget);
      expect(find.byKey(AnimejoyAccountSection.verifyButtonKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('About section handles manual update check outcomes', (
    tester,
  ) async {
    final updateRepo = FakeAppUpdateRepository(
      installed: const AppVersion(1, 5, 1),
    )..failing = true;
    final opened = <Uri>[];
    await pumpSettings(
      tester,
      size: const Size(1280, 800),
      updateRepo: updateRepo,
      onOpenExternalUrl: (url) async {
        opened.add(url);
        return true;
      },
    );

    final checkButton = find.byKey(AboutAppSection.checkUpdatesButtonKey);
    expect(
      find.descendant(of: checkButton, matching: find.text('Check')),
      findsOneWidget,
    );
    await tester.ensureVisible(checkButton);
    await tester.pumpAndSettle();

    // Failed check.
    await tester.tap(checkButton);
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t check'), findsOneWidget);

    // Up to date.
    updateRepo.failing = false;
    final pending = updateRepo.pendingLatest = Completer<AppRelease?>();
    await tester.tap(checkButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final checking = find.text('Checking');
    expect(checking.hitTestable(), findsOneWidget);
    expect(
      tester.getTopLeft(checking).dx,
      tester.getTopLeft(find.text('Version')).dx,
    );
    expect(find.bySemanticsLabel('Checking'), findsOneWidget);
    expect(tester.widget<TextButton>(checkButton).onPressed, isNull);
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Up to date'), findsOneWidget);

    // Newer release available.
    final release = AppRelease(
      version: const AppVersion(1, 6, 0),
      downloadUrl: Uri.parse('https://example.org/iris-1.6.0.exe'),
    );
    updateRepo
      ..pendingLatest = null
      ..latest = release;
    await tester.tap(checkButton);
    await tester.pumpAndSettle();
    expect(find.text('Version 1.6.0 available'), findsOneWidget);

    final openButton = find.byKey(AboutAppSection.openUpdateButtonKey);
    expect(
      find.descendant(of: openButton, matching: find.text('Download')),
      findsOneWidget,
    );
    await tester.ensureVisible(openButton);
    await tester.pumpAndSettle();
    await tester.tap(openButton);
    await tester.pumpAndSettle();
    expect(opened, [release.downloadUrl]);
    expect(tester.takeException(), isNull);
  });

  for (final (layout, size, platform) in const [
    ('phone', Size(320, 700), TargetPlatform.android),
    ('desktop', Size(1280, 800), TargetPlatform.windows),
  ]) {
    testWidgets('About can check for a newer release after Later on $layout', (
      tester,
    ) async {
      final release = testRelease(6);
      final repository = FakeAppUpdateRepository(
        installed: const AppVersion(1, 5, 1),
        latest: release,
        dismissed: release.version,
      );
      await pumpSettings(
        tester,
        size: size,
        textScale: 2,
        platform: platform,
        updateDownloads: _UpdateDownloads(),
        updateRepo: repository,
      );
      final about = find.byType(AboutAppSection);
      await tester.element(about).read<AppUpdateCubit>().check();
      await tester.pumpAndSettle();
      final check = find.byKey(AboutAppSection.checkUpdatesButtonKey);
      final open = find.byKey(AboutAppSection.openUpdateButtonKey);
      await tester.ensureVisible(about);
      await tester.pumpAndSettle();
      expect(check.hitTestable(), findsOneWidget);
      expect(open.hitTestable(), findsOneWidget);
      expect(find.text('Version 1.6.0 available'), findsOneWidget);

      repository.latest = testRelease(7);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(repository.latestReads, 2);
      expect(find.text('Version 1.7.0 available'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'About shows Windows verification, Restart and restart progress',
    (tester) async {
      final downloads = _UpdateDownloads();
      await pumpSettings(
        tester,
        size: const Size(1280, 800),
        platform: TargetPlatform.windows,
        updateDownloads: downloads,
        updateRepo: FakeAppUpdateRepository(
          installed: const AppVersion(1, 5, 1),
          latest: testRelease(6),
        ),
      );
      final check = find.byKey(AboutAppSection.checkUpdatesButtonKey);
      await tester.ensureVisible(check);
      await tester.pumpAndSettle();
      await tester.tap(check);
      await tester.pumpAndSettle();

      final action = find.byKey(AboutAppSection.openUpdateButtonKey);
      expect(
        find.descendant(of: action, matching: find.text('Update')),
        findsOneWidget,
      );
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(UpdateNotice.downloadActionKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      expect(find.text('Downloading · 42%'), findsOneWidget);
      expect(
        find.descendant(of: action, matching: find.text('Details')),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
      final bar = find.byType(SegmentedBar);
      final progressBar = tester.element(bar);
      downloads.progress(100, 100);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Verifying file'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AboutAppSection),
          matching: find.byType(PixelNoise),
        ),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
      expect(tester.element(bar), same(progressBar));
      expect(tester.widget<SegmentedBar>(bar).value, 1);

      downloads.downloaded.complete(r'C:\updates\iris.exe');
      await tester.pumpAndSettle();
      expect(find.text('Ready to restart'), findsOneWidget);
      expect(
        find.descendant(of: action, matching: find.text('Restart')),
        findsOneWidget,
      );
      await tester.tap(action);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Restarting Iris'), findsOneWidget);
      expect(action, findsNothing);
      expect(
        find.descendant(
          of: find.byType(AboutAppSection),
          matching: find.byType(PixelNoise),
        ),
        findsOneWidget,
      );
      expect(downloads.installPath, r'C:\updates\iris.exe');
      downloads.installed.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'About shows a static status beside an unknown-size download spinner',
    (tester) async {
      final downloads = _UpdateDownloads();
      await pumpSettings(
        tester,
        size: const Size(1280, 800),
        platform: TargetPlatform.windows,
        updateDownloads: downloads,
        updateRepo: FakeAppUpdateRepository(
          installed: const AppVersion(1, 5, 1),
          latest: testRelease(6),
        ),
      );
      final check = find.byKey(AboutAppSection.checkUpdatesButtonKey);
      await tester.ensureVisible(check);
      await tester.pumpAndSettle();
      await tester.tap(check);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AboutAppSection.openUpdateButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(UpdateNotice.downloadActionKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      downloads.progress(12 * 1024 * 1024, 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final about = find.byType(AboutAppSection);
      expect(
        find.descendant(of: about, matching: find.byType(BlockSpinner)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: about, matching: find.byType(PixelNoise)),
        findsNothing,
      );
    },
  );

  testWidgets('the Russian phone About row keeps its status by the version', (
    tester,
  ) async {
    await pumpSettings(tester, locale: const Locale('ru'));
    final check = find.widgetWithText(TextButton, 'Проверить');
    await tester.ensureVisible(check);
    await tester.pumpAndSettle();
    await tester.tap(check);
    await tester.pumpAndSettle();

    final version = find.text('Версия');
    final status = find.text('Актуальная версия');
    expect(version.hitTestable(), findsOneWidget);
    expect(status.hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(status).dx, tester.getTopLeft(version).dx);
    expect(
      tester.getTopLeft(status).dy,
      greaterThan(tester.getBottomLeft(version).dy),
    );
    expect(
      find.text('Дорожки по умолчанию для торрентов, пока не выбраны в плеере'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the desktop update dialog opens after Settings is dismissed', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      size: const Size(1280, 800),
      updateRepo: FakeAppUpdateRepository(
        installed: const AppVersion(1, 5, 1),
        latest: testRelease(6),
      ),
      asDialog: true,
      updateDownloads: _UpdateDownloads(),
      platform: TargetPlatform.windows,
    );
    await tester.tap(find.byKey(AboutAppSection.checkUpdatesButtonKey));
    await tester.pumpAndSettle();

    final update = find.byKey(UpdateNotice.sheetKey);
    final open = find.byKey(AboutAppSection.openUpdateButtonKey);
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pump();
    expect(update, findsNothing);
    await tester.pumpAndSettle();

    expect(update, findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Accounts'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Open settings').hitTestable(), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('About is reachable in a short Settings dialog at 200% text', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      size: const Size(620, 420),
      locale: const Locale('ru'),
      textScale: 2,
      asDialog: true,
    );
    final check = find.widgetWithText(TextButton, 'Проверить');
    await tester.ensureVisible(check);
    await tester.pumpAndSettle();
    await tester.tap(check);
    await tester.pumpAndSettle();

    final status = find.text('Актуальная версия');
    await tester.ensureVisible(status);
    await tester.pumpAndSettle();
    expect(status.hitTestable(), findsOneWidget);
    expect(find.byType(CloseButton).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('About section hides update check when not supported', (
    tester,
  ) async {
    final updateRepo = FakeAppUpdateRepository(
      installed: const AppVersion(1, 5, 1),
      supportsCheck: false,
    );
    await pumpSettings(tester, updateRepo: updateRepo);

    expect(find.text('1.5.1'), findsOneWidget);
    expect(find.byKey(AboutAppSection.checkUpdatesButtonKey), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('an unreadable installed version does not report up to date', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      size: const Size(1280, 800),
      updateRepo: FakeAppUpdateRepository(latest: testRelease(6)),
    );
    final checkButton = find.byKey(AboutAppSection.checkUpdatesButtonKey);
    await tester.ensureVisible(checkButton);
    await tester.pumpAndSettle();
    await tester.tap(checkButton);
    await tester.pumpAndSettle();
    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('Couldn’t check'), findsOneWidget);
  });
}

class _UpdateDownloads extends Fake implements AppUpdateDownloadRepository {
  final downloaded = Completer<String>();
  final installed = Completer<void>();
  late void Function(int received, int total) progress;
  String? installPath;

  @override
  Future<String?> restore(AppRelease release) async => null;

  @override
  Future<String> download(
    AppRelease release, {
    required void Function(int received, int total) onProgress,
  }) {
    progress = onProgress;
    onProgress(42, 100);
    return downloaded.future;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> canInstall() async => true;

  @override
  Future<void> install(String path) {
    installPath = path;
    return installed.future;
  }
}
