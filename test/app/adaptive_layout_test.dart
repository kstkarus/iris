import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/app/router/app_shell_page.dart';
import 'package:iris/main.dart';

import '../helpers/test_window.dart';

const _firstTitle = 'Fullmetal Alchemist: Brotherhood';
const _secondTitle = 'Frieren: Beyond Journey\'s End';
const _description =
    'Two brothers search for a Philosopher\'s Stone after a failed ritual.';

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  const step = Duration(milliseconds: 16);
  var elapsed = Duration.zero;
  while (elapsed < timeout) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    elapsed += step;
  }
  fail('Widget was not found within $timeout: $finder');
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

const _sourceWatchButton = Key('watch_source_watch_button');
const _sourceDownloadButton = Key('watch_source_download_button');

Future<void> _openWatchSources(WidgetTester tester) async {
  await _tapAndSettle(
    tester,
    find.widgetWithText(FilledButton, 'Choose source'),
  );
  await _pumpUntilVisible(tester, find.text('Watch sources'));
  await tester.pumpAndSettle();
}

Future<void> _pumpMockApp(WidgetTester tester, Size size) async {
  setTestWindowSize(tester, size);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(await createApp(useMocks: true));
  await _pumpUntilVisible(tester, find.text(_firstTitle));
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in TestWindowSizes.all.entries) {
    final sizeName = entry.key;
    final size = entry.value;
    final isPhone = size.width < 600;
    final isDesktop = size.width >= 1200;

    testWidgets('shell uses the right navigation on $sizeName', (tester) async {
      await _pumpMockApp(tester, size);

      expect(
        find.byKey(AppShellPage.navigationBarKey),
        isPhone ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(AppShellPage.navigationRailKey),
        isPhone ? findsNothing : findsOneWidget,
      );
      if (!isPhone) {
        final rail = tester.widget<NavigationRail>(
          find.byKey(AppShellPage.navigationRailKey),
        );
        expect(rail.extended, isDesktop);
      }

      await tester.tap(find.text('Downloads').first);
      await tester.pumpAndSettle();

      expect(find.text('App storage'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('catalog to downloads flow has no overflow on $sizeName', (
      tester,
    ) async {
      await _pumpMockApp(tester, size);

      final firstCard = tester.getTopLeft(find.text(_firstTitle));
      final secondCard = tester.getTopLeft(find.text(_secondTitle));
      if (isPhone) {
        expect(secondCard.dy, greaterThan(firstCard.dy));
      } else {
        expect(secondCard.dy, firstCard.dy, reason: 'cards share a row');
        expect(secondCard.dx, greaterThan(firstCard.dx));
      }
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(_firstTitle));
      await _pumpUntilVisible(
        tester,
        find.widgetWithText(FilledButton, 'Choose source'),
      );
      await tester.pumpAndSettle();

      final poster = tester.getRect(find.byType(Image).first);
      final title = tester.getRect(find.text(_firstTitle));
      final description = tester.getRect(find.text(_description));
      if (isPhone) {
        expect(description.left, title.left, reason: 'single column');
      } else {
        expect(
          description.left,
          greaterThan(poster.right),
          reason: 'two panes',
        );
      }
      expect(tester.takeException(), isNull);

      await _openWatchSources(tester);
      expect(tester.takeException(), isNull);

      await _tapAndSettle(tester, find.byKey(_sourceDownloadButton).first);
      await _pumpUntilVisible(tester, find.text('episode-01'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await _tapAndSettle(tester, find.byTooltip('Download').first);
      await _pumpUntilVisible(tester, find.text('Watch'));
      await tester.pumpAndSettle();

      final storage = tester.getRect(find.text('App storage'));
      final watch = tester.getRect(find.text('Watch'));
      if (size.width >= 840) {
        expect(storage.left, greaterThan(watch.right), reason: 'side pane');
      } else {
        expect(storage.top, lessThan(watch.top), reason: 'storage on top');
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final entry in TestWindowSizes.all.entries) {
    testWidgets('catalog to streaming player flow has no overflow on '
        '${entry.key}', (tester) async {
      await _pumpMockApp(tester, entry.value);
      await tester.tap(find.text(_firstTitle));
      await _pumpUntilVisible(
        tester,
        find.widgetWithText(FilledButton, 'Choose source'),
      );
      await tester.pumpAndSettle();

      await _openWatchSources(tester);
      final watch = tester.getRect(find.byKey(_sourceWatchButton).first);
      final download = tester.getRect(find.byKey(_sourceDownloadButton).first);
      expect(
        watch.contains(download.center),
        isTrue,
        reason: 'download is the row trailing action',
      );
      expect(tester.takeException(), isNull);

      await _tapAndSettle(tester, find.byKey(_sourceWatchButton).first);
      await _pumpUntilVisible(tester, find.text('episode-01'));
      await tester.pumpAndSettle();

      expect(find.text('Choose File'), findsOneWidget);
      final fileCard = tester.getRect(
        find
            .ancestor(
              of: find.text('episode-01'),
              matching: find.byType(ListTile),
            )
            .first,
      );
      expect(
        fileCard.width,
        lessThanOrEqualTo(840),
        reason: 'file list width is capped on wide windows',
      );
      expect(tester.takeException(), isNull);

      await _tapAndSettle(tester, find.text('episode-01').first);
      await _pumpUntilVisible(
        tester,
        find.byKey(const Key('mock_player_surface')),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('filters open in a dialog on wide windows', (tester) async {
    await _pumpMockApp(tester, TestWindowSizes.desktop);

    await tester.tap(find.text('Filter & Sort'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Apply'), findsOneWidget);
  });

  testWidgets('filters open in a bottom sheet on phones', (tester) async {
    await _pumpMockApp(tester, TestWindowSizes.phone);

    await tester.tap(find.text('Filter & Sort'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Apply'), findsOneWidget);
  });
}
