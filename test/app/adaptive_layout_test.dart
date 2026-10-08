import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/app/router/app_shell_page.dart';
import 'package:iris/main.dart';
import 'package:iris/shared/widgets/dithered_image.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';

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
  for (final entry in TestWindowSizes.all.entries) {
    final sizeName = entry.key;
    final size = entry.value;
    final isPhone = size.width < 600;

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

      await tester.tap(find.text('Downloads').first);
      await tester.pumpAndSettle();

      expect(find.text('APP STORAGE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('catalog to downloads flow has no overflow on $sizeName', (
      tester,
    ) async {
      await _pumpMockApp(tester, size);

      // Covers sit side by side even on phones.
      final firstCard = tester.getTopLeft(find.text(_firstTitle));
      final secondCard = tester.getTopLeft(find.text(_secondTitle));
      expect(secondCard.dy, firstCard.dy, reason: 'cards share a row');
      expect(secondCard.dx, greaterThan(firstCard.dx));
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text(_firstTitle));
      await tester.pump();
      await tester.tap(find.text(_firstTitle));
      await _pumpUntilVisible(
        tester,
        find.widgetWithText(FilledButton, 'Choose source'),
      );
      await tester.pumpAndSettle();

      final poster = tester.getRect(find.byType(DitheredImage).first);
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
      await _pumpUntilVisible(tester, find.byTooltip('Watch'));
      await tester.pumpAndSettle();

      final storage = tester.getRect(find.text('APP STORAGE'));
      final watch = tester.getRect(find.byTooltip('Watch'));
      // Content of 840 dp and up gets a side pane; narrower stacks the
      // panes, files first.
      if (size.width >= 900) {
        expect(storage.left, greaterThan(watch.right), reason: 'side pane');
      } else {
        expect(storage.top, greaterThan(watch.top), reason: 'files first');
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final entry in TestWindowSizes.all.entries) {
    testWidgets('catalog to streaming player flow has no overflow on '
        '${entry.key}', (tester) async {
      await _pumpMockApp(tester, entry.value);
      await tester.ensureVisible(find.text(_firstTitle));
      await tester.pump();
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
        find.byKey(const ValueKey('player_episode_0')),
      );
      expect(
        fileCard.width,
        lessThanOrEqualTo(AdaptiveContentWidth.page),
        reason: 'the file list keeps to the shared page frame',
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

  testWidgets('the top bar keeps to the page frame, sections centred', (
    tester,
  ) async {
    const size = TestWindowSizes.desktop;
    await _pumpMockApp(tester, size);

    final sections = tester
        .getRect(find.text('Catalog').first)
        .expandToInclude(tester.getRect(find.text('Downloads').first));
    expect(sections.center.dx, closeTo(size.width / 2, 12));
    // The mark sits over the content's left edge: the frame is centred.
    final mark = tester.getRect(
      find.ancestor(of: find.text('iris'), matching: find.byType(Row)).first,
    );
    expect(mark.left, (size.width - AdaptiveContentWidth.page) / 2);
  });

  for (final width in const [600.0, 720.0, 840.0]) {
    testWidgets('top bar sections stay in reach at ${width.toInt()} dp in '
        'Russian at 2.0 text', (tester) async {
      _useRussianAtDoubleText(tester);
      await _pumpMockApp(tester, Size(width, 900));

      expect(tester.takeException(), isNull);
      final bar = find.byKey(AppShellPage.navigationRailKey);
      final barRect = tester.getRect(bar);
      for (final label in const ['Каталог', 'Раздачи', 'Загрузки']) {
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
        expect(tester.takeException(), isNull, reason: label);
      }
    });
  }

  testWidgets('bottom tabs show whole words at 320 dp in Russian at 2.0 '
      'text', (tester) async {
    _useRussianAtDoubleText(tester);
    await _pumpMockApp(tester, const Size(320, 720));

    final bar = find.byKey(AppShellPage.navigationBarKey);
    for (final label in const ['Каталог', 'Раздачи', 'Загрузки']) {
      final text = find.descendant(of: bar, matching: find.text(label));
      final paragraph = tester.renderObject<RenderParagraph>(text);
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      final tab = tester.getRect(
        find.ancestor(of: text, matching: find.byType(InkWell)),
      );
      final shown = tester.getRect(text);
      expect(shown.left, greaterThanOrEqualTo(tab.left - 0.5), reason: label);
      expect(shown.right, lessThanOrEqualTo(tab.right + 0.5), reason: label);
    }
    expect(tester.takeException(), isNull);
  });

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

    // Narrow windows show the action as an icon, named by its tooltip.
    await tester.tap(find.byTooltip('Filter & Sort'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Apply'), findsOneWidget);
  });
}
