import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/app/router/app_shell_page.dart';

import 'helpers/mock_app.dart';

void main() {
  testWidgets('App opens details after tapping an anime card', (tester) async {
    await pumpMockApp(tester);

    expect(find.text('Iris'), findsNothing);
    // The navigation names the section; the page does not repeat it.
    expect(find.byType(AppBar), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(AppShellPage.topBarKey),
        matching: find.text('Catalog'),
      ),
      findsOneWidget,
    );
    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);

    // Covers start under the catalog's heading.
    await _tapVisible(tester, find.text('Fullmetal Alchemist: Brotherhood'));
    await tester.pump();
    await pumpUntilVisible(
      tester,
      find.widgetWithText(FilledButton, 'Choose source'),
    );

    expect(find.widgetWithText(FilledButton, 'Choose source'), findsOneWidget);
    expect(
      find.text(
        'Two brothers search for a Philosopher\'s Stone after a failed ritual.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('App opens watch sources after tapping Watch on details', (
    tester,
  ) async {
    await pumpMockApp(tester);
    await _openWatchSources(tester);

    expect(find.text('Watch sources'), findsOneWidget);
    expect(
      find.text('[Mock] Fullmetal Alchemist: Brotherhood Batch'),
      findsOneWidget,
    );
    expect(find.byKey(_sourceWatchButton), findsWidgets);
    expect(find.byKey(_sourceDownloadButton), findsWidgets);
  });

  testWidgets('App opens player from a completed download', (tester) async {
    await pumpMockApp(tester);
    await _openWatchSources(tester);

    await _tapVisible(tester, find.byKey(_sourceDownloadButton).last);
    await pumpUntilVisible(tester, find.text('Download a file'));
    await tester.pumpAndSettle();
    expect(find.text('episode-01'), findsOneWidget);

    await tester.tap(find.byTooltip('Download').first);
    await pumpUntilVisible(tester, find.byTooltip('Watch'));
    // Let the route transition back to the shell finish before tapping.
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byTooltip('Watch'));
    await pumpUntilVisible(tester, _playerSurface);

    expect(find.byKey(const Key('mock_player_surface')), findsOneWidget);
  });

  testWidgets('App streams a saved magnet independently of the catalog', (
    tester,
  ) async {
    await pumpMockApp(tester);

    await _tapVisible(tester, find.text('Torrents'));
    await pumpUntilVisible(tester, find.text('No saved torrents yet'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Add torrent').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('add_saved_torrent_magnet_field')),
      'magnet:?xt=urn:btih:065c4691de84f964e143103b3bd0de17be5bfd0a'
      '&dn=My%20Own%20Release',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('add_saved_torrent_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('My Own Release'), findsOneWidget);

    await _tapVisible(
      tester,
      find.byKey(const Key('saved_torrent_watch_button')),
    );
    await pumpUntilVisible(tester, find.text('Choose File'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('episode-01').first);
    await pumpUntilVisible(tester, _playerSurface);

    expect(find.byKey(const Key('mock_player_surface')), findsOneWidget);

    // The mock player reports 5:00 of 24:00; leaving keeps that progress.
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Episode 1 · 5:00 / 24:00'), findsOneWidget);
    // The default test window is too narrow for the row's verb label; the
    // progress itself sits inside the tappable row.
    expect(
      find.descendant(
        of: find.byKey(const Key('saved_torrent_watch_button')),
        matching: find.text('Episode 1 · 5:00 / 24:00'),
      ),
      findsOneWidget,
    );

    await _tapVisible(
      tester,
      find.descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              widget.key == AppShellPage.navigationBarKey ||
              widget.key == AppShellPage.topBarKey,
        ),
        matching: find.text('Catalog'),
      ),
    );
    await tester.pumpAndSettle();
    final continueCard = find.descendant(
      of: find.byKey(const Key('continue_watching_row')),
      matching: find.text('My Own Release'),
    );
    expect(continueCard, findsOneWidget);

    // Continue skips the file picker and resumes the saved position.
    await _tapVisible(
      tester,
      find.descendant(
        of: find.byKey(const Key('continue_watching_row')),
        matching: find.widgetWithText(FilledButton, 'Continue'),
      ),
    );
    await pumpUntilVisible(tester, _playerSurface);
    // Not pumpAndSettle: the notice's countdown would run out meanwhile.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Resumed from 5:00'), findsOneWidget);
    expect(find.text('Start over'), findsOneWidget);

    // On this landscape window the episodes pane sits beside the video and
    // switches files in place.
    final episodes = find.byKey(const Key('player_episodes_pane'));
    expect(episodes, findsOneWidget);
    expect(
      find.descendant(of: episodes, matching: find.text('NOW PLAYING')),
      findsOneWidget,
    );
    await _tapVisible(tester, find.byKey(const ValueKey('player_episode_1')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('episode-02'),
      ),
      findsOneWidget,
    );
    expect(_playerSurface, findsOneWidget);
  });
}

const _sourceWatchButton = Key('watch_source_watch_button');
final _playerSurface = find.byKey(const Key('mock_player_surface'));
const _sourceDownloadButton = Key('watch_source_download_button');

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _openWatchSources(WidgetTester tester) async {
  // Covers start under the catalog's heading.
  await _tapVisible(tester, find.text('Fullmetal Alchemist: Brotherhood'));
  await pumpUntilVisible(
    tester,
    find.widgetWithText(FilledButton, 'Choose source'),
  );
  await tester.pumpAndSettle();

  await _tapVisible(tester, find.widgetWithText(FilledButton, 'Choose source'));
  await pumpUntilVisible(tester, find.text('Watch sources'));
  await tester.pumpAndSettle();
}
