import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/main.dart';

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
  Duration step = const Duration(milliseconds: 16),
}) async {
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

Future<void> _pumpMockApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(await createApp(useMocks: true));
  await _pumpUntilVisible(tester, find.widgetWithText(AppBar, 'Catalog'));
}

void main() {
  testWidgets('App opens details after tapping an anime card', (tester) async {
    await _pumpMockApp(tester);

    expect(find.text('Iris'), findsNothing);
    expect(find.widgetWithText(AppBar, 'Catalog'), findsOneWidget);
    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);

    await tester.tap(find.text('Fullmetal Alchemist: Brotherhood'));
    await tester.pump();
    await _pumpUntilVisible(
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
    await _pumpMockApp(tester);
    await _openWatchSources(tester);

    expect(find.text('Watch sources'), findsOneWidget);
    expect(
      find.text('[Mock] Fullmetal Alchemist: Brotherhood Batch'),
      findsOneWidget,
    );
    expect(find.byKey(_sourceWatchButton), findsWidgets);
    expect(find.byKey(_sourceDownloadButton), findsWidgets);
  });

  testWidgets('App streams a source through the file picker into the player', (
    tester,
  ) async {
    await _pumpMockApp(tester);
    await _openWatchSources(tester);

    await _tapVisible(tester, find.byKey(_sourceWatchButton).last);
    await _pumpUntilVisible(tester, find.text('Choose File'));
    await tester.pumpAndSettle();

    expect(find.text('Choose File'), findsOneWidget);
    expect(find.text('episode-01'), findsOneWidget);
    expect(find.text('episode-02'), findsOneWidget);

    await _tapVisible(tester, find.text('episode-01').first);
    await _pumpUntilVisible(tester, _playerSurface);

    expect(find.byKey(const Key('mock_player_surface')), findsOneWidget);
  });

  testWidgets('App opens download file selection from a source', (
    tester,
  ) async {
    await _pumpMockApp(tester);
    await _openWatchSources(tester);

    await _tapVisible(tester, find.byKey(_sourceDownloadButton).last);
    await _pumpUntilVisible(tester, find.text('Download a file'));

    expect(find.text('Download a file'), findsOneWidget);
    expect(find.text('episode-01'), findsOneWidget);
  });

  testWidgets('App opens player from a completed download', (tester) async {
    await _pumpMockApp(tester);
    await _openWatchSources(tester);

    await _tapVisible(tester, find.byKey(_sourceDownloadButton).last);
    await _pumpUntilVisible(tester, find.text('Download a file'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Download').first);
    await _pumpUntilVisible(tester, find.text('Watch'));
    // Let the route transition back to the shell finish before tapping.
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Watch'));
    await _pumpUntilVisible(tester, _playerSurface);

    expect(find.byKey(const Key('mock_player_surface')), findsOneWidget);
  });

  testWidgets('App streams a saved magnet independently of the catalog', (
    tester,
  ) async {
    await _pumpMockApp(tester);

    await _tapVisible(tester, find.text('Torrents'));
    await _pumpUntilVisible(tester, find.text('No saved torrents yet'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Add magnet').last);
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
    await _pumpUntilVisible(tester, find.text('Choose File'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('episode-01').first);
    await _pumpUntilVisible(tester, _playerSurface);

    expect(find.byKey(const Key('mock_player_surface')), findsOneWidget);

    // The mock player reports 5:00 of 24:00; leaving keeps that progress.
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Last watched: episode-01'), findsOneWidget);
    expect(find.text('Stopped at 5:00 of 24:00'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('saved_torrent_watch_button')),
        matching: find.text('Continue'),
      ),
      findsOneWidget,
    );

    await _tapVisible(
      tester,
      find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is NavigationBar || widget is NavigationRail,
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
    await _tapVisible(tester, continueCard);
    await _pumpUntilVisible(tester, _playerSurface);
    await tester.pumpAndSettle();
    expect(find.text('Resumed from 5:00'), findsOneWidget);
    expect(find.text('Start over'), findsOneWidget);

    // On this landscape window the episodes pane sits beside the video and
    // switches files in place.
    final episodes = find.byKey(const Key('player_episodes_pane'));
    expect(episodes, findsOneWidget);
    expect(
      find.descendant(of: episodes, matching: find.text('Now playing')),
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
  await tester.tap(find.text('Fullmetal Alchemist: Brotherhood'));
  await _pumpUntilVisible(
    tester,
    find.widgetWithText(FilledButton, 'Choose source'),
  );
  await tester.pumpAndSettle();

  await _tapVisible(tester, find.widgetWithText(FilledButton, 'Choose source'));
  await _pumpUntilVisible(tester, find.text('Watch sources'));
  await tester.pumpAndSettle();
}
