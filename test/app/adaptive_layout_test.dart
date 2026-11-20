import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/app/router/app_shell_page.dart';
import 'package:iris/app/di/service_locator.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/downloads/presentation/pages/download_selection_page.dart';
import 'package:iris/features/downloads/presentation/widgets/download_queue.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_list_view.dart';
import 'package:iris/features/profile/presentation/pages/profile_page.dart';
import 'package:iris/features/settings/presentation/pages/settings_page.dart';
import 'package:iris/shared/widgets/page_title.dart';

import '../helpers/mock_app.dart';
import '../helpers/test_window.dart';

const _firstTitle = 'Fullmetal Alchemist: Brotherhood';

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

const _sourceWatchButton = Key('watch_source_watch_button');
const _sourceDownloadButton = Key('watch_source_download_button');
const _firstPlayerEpisode = ValueKey('player_episode_0');

Future<void> _openWatchSources(WidgetTester tester) async {
  await _tapAndSettle(
    tester,
    find.widgetWithText(FilledButton, 'Choose source'),
  );
  await pumpUntilVisible(tester, find.text('Watch sources'));
  await tester.pumpAndSettle();
}

/// Russian labels at 2.0 text: the longest section name is the hard case.
void _useRussianAtDoubleText(WidgetTester tester) {
  final dispatcher = tester.platformDispatcher;
  dispatcher
    ..localeTestValue = const Locale('ru')
    ..localesTestValue = const [Locale('ru')]
    ..textScaleFactorTestValue = 2;
  addTearDown(() {
    dispatcher
      ..clearLocaleTestValue()
      ..clearLocalesTestValue()
      ..clearTextScaleFactorTestValue();
  });
}

void main() {
  testWidgets('queue Back returns to downloads and Files opens the title', (
    tester,
  ) async {
    await pumpMockApp(tester, size: TestWindowSizes.phone);
    final repository = serviceLocator<DownloadsRepository>();
    final source = await repository.prepareSource(magnet: 'mock');
    final item = await repository.enqueueDownload(
      source: source,
      file: source.files.first,
      animeId: '5114',
      animeTitle: _firstTitle,
      sourceTitle: 'Mock release',
    );
    await repository.resume(id: item.id);
    await tester.tap(find.text('Downloads').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('download_queue_open')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('queue_handle_${item.id}')), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('download_files_open')), findsOneWidget);
    await tester.tap(find.byKey(const Key('download_queue_open')));
    await tester.pumpAndSettle();
    tester.widget<DownloadQueueView>(find.byType(DownloadQueueView)).onFiles();
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('download_files_sheet')),
        matching: find.text(_firstTitle),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Episode 01'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('download_title_anime:5114')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop gear and shortcut open a single Settings dialog over the tab',
    (tester) async {
      await pumpMockApp(tester, size: TestWindowSizes.desktop);

      Future<void> ctrl(LogicalKeyboardKey key) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }

      await ctrl(LogicalKeyboardKey.digit2);
      final router = GoRouter.of(tester.element(find.byType(AppShellPage)));
      expect(router.state.uri.path, '/downloads');

      await ctrl(LogicalKeyboardKey.digit4);
      expect(tester.takeException(), isNull);
      expect(router.state.uri.path, '/downloads');
      await ctrl(LogicalKeyboardKey.digit3);
      expect(router.state.uri.path, '/profile');
      await ctrl(LogicalKeyboardKey.digit1);
      expect(router.state.uri.path, '/');

      await tester.tap(find.byKey(AppShellPage.settingsButtonKey));
      await tester.pumpAndSettle();
      final dialog = find.byType(Dialog);
      expect(dialog, findsOneWidget);
      expect(router.state.uri.path, '/');
      expect(find.text(_firstTitle), findsOneWidget);

      // Pressing the shortcut again leaves just one route to dismiss.
      await ctrl(LogicalKeyboardKey.comma);
      await ctrl(LogicalKeyboardKey.comma);
      expect(dialog, findsOneWidget);

      final close = find.descendant(
        of: dialog,
        matching: find.byType(CloseButton),
      );
      final dismiss = [
        () => tester.sendKeyEvent(LogicalKeyboardKey.escape),
        () => tester.tap(close),
        () => tester.tapAt(const Offset(8, 8)),
      ];
      for (final closeDialog in dismiss) {
        await closeDialog();
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(router.state.uri.path, '/');
        await ctrl(LogicalKeyboardKey.comma);
        expect(dialog, findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop Settings and its playback menu follow the selected theme',
    (tester) async {
      await pumpMockApp(tester, size: const Size(1280, 800));
      await tester.tap(find.byKey(AppShellPage.settingsButtonKey));
      await tester.pumpAndSettle();

      final dialog = find.byType(Dialog);
      for (final (label, brightness) in [
        ('Dark', Brightness.dark),
        ('Light', Brightness.light),
      ]) {
        await tester.tap(
          find.descendant(of: dialog, matching: find.text(label)),
        );
        await tester.pumpAndSettle();
        expect(Theme.of(tester.element(dialog)).brightness, brightness);

        await tester.tap(
          find.byKey(const Key('settings_default_audio_choice')),
        );
        await tester.pumpAndSettle();
        final option = find.widgetWithText(MenuItemButton, 'Japanese');
        expect(option.hitTestable(), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(option, findsNothing);
        expect(dialog, findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the Settings route still renders a full page on desktop', (
    tester,
  ) async {
    await pumpMockApp(tester, size: const Size(1280, 800));
    GoRouter.of(tester.element(find.byType(AppShellPage))).go('/settings');
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Accounts').hitTestable(), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone Profile opens Settings and Back returns to Profile', (
    tester,
  ) async {
    await pumpMockApp(tester, size: const Size(390, 640));
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    final gear = find.byKey(ProfilePage.settingsButtonKey);
    await tester.tap(gear);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(
      GoRouter.of(tester.element(find.byType(SettingsPage))).state.uri.path,
      '/settings',
    );
    expect(find.byType(PageTitle), findsNothing);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(PageTitle, 'Settings'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(gear.hitTestable(), findsOneWidget);
  });

  for (final entry in TestWindowSizes.all.entries) {
    final sizeName = entry.key;
    final size = entry.value;

    testWidgets('catalog to downloads flow has no overflow on $sizeName', (
      tester,
    ) async {
      await pumpMockApp(tester, size: size);

      await tester.ensureVisible(find.text(_firstTitle));
      await tester.pump();
      await tester.tap(find.text(_firstTitle));
      await pumpUntilVisible(
        tester,
        find.widgetWithText(FilledButton, 'Choose source'),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await _openWatchSources(tester);
      expect(tester.takeException(), isNull);

      await _tapAndSettle(tester, find.byKey(_sourceDownloadButton).first);
      await pumpUntilVisible(
        tester,
        find.byKey(const ValueKey('download_file_button_0')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await _tapAndSettle(tester, find.byTooltip('Download').first);
      // The picker stays, its row done, at every width.
      await pumpUntilVisible(
        tester,
        find.byKey(const ValueKey('download_file_watch_0')),
      );
      expect(tester.takeException(), isNull);

      GoRouter.of(
        tester.element(find.byType(DownloadSelectionPage)),
      ).goNamed('downloads');
      await pumpUntilVisible(
        tester,
        find.byKey(const ValueKey('download_title_anime:5114')),
      );
      await tester.pumpAndSettle();

      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('download_title_anime:5114')),
      );
      await pumpUntilVisible(tester, find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      await _tapAndSettle(tester, find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('download_title_anime:5114')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final entry in TestWindowSizes.all.entries) {
    testWidgets('catalog to streaming player flow has no overflow on '
        '${entry.key}', (tester) async {
      await pumpMockApp(tester, size: entry.value);
      await tester.ensureVisible(find.text(_firstTitle));
      await tester.pump();
      await tester.tap(find.text(_firstTitle));
      await pumpUntilVisible(
        tester,
        find.widgetWithText(FilledButton, 'Choose source'),
      );
      await tester.pumpAndSettle();

      await _openWatchSources(tester);
      expect(tester.takeException(), isNull);

      await _tapAndSettle(tester, find.byKey(_sourceWatchButton).first);
      await pumpUntilVisible(tester, find.byKey(_firstPlayerEpisode));
      await tester.pumpAndSettle();

      expect(find.text('Choose File'), findsOneWidget);
      expect(find.byKey(const ValueKey('player_episode_1')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _tapAndSettle(tester, find.byKey(_firstPlayerEpisode));
      await pumpUntilVisible(
        tester,
        find.byKey(const Key('mock_player_surface')),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the pages under the player turn with the phone without '
      'overflow', (tester) async {
    await pumpMockApp(tester, size: TestWindowSizes.phone);
    await tester.ensureVisible(find.text(_firstTitle));
    await tester.pump();
    await tester.tap(find.text(_firstTitle));
    await pumpUntilVisible(
      tester,
      find.widgetWithText(FilledButton, 'Choose source'),
    );
    await tester.pumpAndSettle();
    await _openWatchSources(tester);
    await _tapAndSettle(tester, find.byKey(_sourceWatchButton).first);
    await pumpUntilVisible(tester, find.byKey(_firstPlayerEpisode));
    await tester.pumpAndSettle();
    await _tapAndSettle(tester, find.byKey(_firstPlayerEpisode));
    await pumpUntilVisible(
      tester,
      find.byKey(const Key('mock_player_surface')),
    );

    // The player turns the phone sideways; the pages below lay out again.
    final landscape = Size(
      TestWindowSizes.phone.height,
      TestWindowSizes.phone.width,
    );
    setTestWindowSize(tester, landscape);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('player_back_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mock_player_surface')), findsNothing);
    expect(tester.takeException(), isNull);

    setTestWindowSize(tester, TestWindowSizes.phone);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final width in const [600.0, 840.0]) {
    testWidgets('top bar sections stay in reach at ${width.toInt()} dp in '
        'Russian at 2.0 text', (tester) async {
      _useRussianAtDoubleText(tester);
      await pumpMockApp(tester, size: Size(width, 900));

      expect(tester.takeException(), isNull);
      final bar = find.byKey(AppShellPage.topBarKey);
      final barRect = tester.getRect(bar);
      for (final entry in const {
        'Каталог': '/',
        'Загрузки': '/downloads',
        'Профиль': '/profile',
      }.entries) {
        final label = entry.key;
        final section = find.ancestor(
          of: find.descendant(of: bar, matching: find.text(label)),
          matching: find.byType(InkWell),
        );
        await tester.ensureVisible(section);
        await tester.pump();
        final rect = tester.getRect(section);
        expect(rect.left, greaterThanOrEqualTo(barRect.left), reason: label);
        expect(rect.right, lessThanOrEqualTo(barRect.right), reason: label);

        await tester.tap(section);
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          GoRouter.of(tester.element(section)).state.uri.path,
          entry.value,
        );
        expect(tester.takeException(), isNull, reason: label);
      }
    });
  }

  testWidgets('bottom tabs show whole words at 320 dp in Russian at 2.0 '
      'text', (tester) async {
    _useRussianAtDoubleText(tester);
    await pumpMockApp(tester, size: const Size(320, 720));

    final bar = find.byKey(AppShellPage.navigationBarKey);
    for (final entry in const {
      'Каталог': '/',
      'Загрузки': '/downloads',
      'Профиль': '/profile',
    }.entries) {
      final label = entry.key;
      final text = find.descendant(of: bar, matching: find.text(label));
      final paragraph = tester.renderObject<RenderParagraph>(text);
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      final tab = find.ancestor(of: text, matching: find.byType(InkWell));
      expect(tab.hitTestable(), findsOneWidget);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(GoRouter.of(tester.element(tab)).state.uri.path, entry.value);
    }
    expect(tester.takeException(), isNull);
  });

  for (final size in [TestWindowSizes.phone, TestWindowSizes.desktop]) {
    testWidgets('catalog applies filters at ${size.width.toInt()} dp', (
      tester,
    ) async {
      await pumpMockApp(tester, size: size);
      final bloc = tester
          .element(find.byType(AnimeListView))
          .read<AnimeListBloc>();
      await tester.tap(
        size.width < 600
            ? find.byTooltip('Filter & Sort')
            : find.text('Filter & Sort'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Movie'));
      await tester.tap(find.widgetWithText(FilledButton, 'Show'));
      await tester.pumpAndSettle();
      expect(bloc.state.filters.kinds, {AnimeKindFilter.movie});
      expect(find.text('Movie'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
