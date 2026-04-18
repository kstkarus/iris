import 'package:flutter/widgets.dart';
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
  await _pumpUntilVisible(tester, find.text('Anime List'));
}

void main() {
  testWidgets('App opens details after tapping an anime card', (tester) async {
    await _pumpMockApp(tester);

    expect(find.text('Iris'), findsOneWidget);
    expect(find.text('Anime List'), findsOneWidget);
    expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);

    await tester.tap(find.text('Fullmetal Alchemist: Brotherhood'));
    await tester.pump();
    await _pumpUntilVisible(tester, find.text('Anime Details'));

    expect(find.text('Anime Details'), findsOneWidget);
    expect(
      find.text(
        'Two brothers search for a Philosopher\'s Stone after a failed ritual.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('App opens watch sources after tapping watch button', (
    tester,
  ) async {
    await _pumpMockApp(tester);

    await tester.tap(find.text('Fullmetal Alchemist: Brotherhood'));
    await _pumpUntilVisible(tester, find.text('Anime Details'));

    expect(find.text('Watch'), findsOneWidget);

    await tester.ensureVisible(find.text('Watch'));
    await tester.pump();
    await tester.tap(find.text('Watch'));
    await tester.pump();
    await _pumpUntilVisible(tester, find.text('Watch Sources'));

    expect(find.text('Watch Sources'), findsOneWidget);
    expect(
      find.text('[Mock] Fullmetal Alchemist: Brotherhood Batch'),
      findsOneWidget,
    );
  });

  testWidgets('App opens file selection after tapping play on a watch source', (
    tester,
  ) async {
    await _pumpMockApp(tester);

    await tester.tap(find.text('Fullmetal Alchemist: Brotherhood'));
    await _pumpUntilVisible(tester, find.text('Anime Details'));

    await tester.ensureVisible(find.text('Watch'));
    await tester.pump();
    await tester.tap(find.text('Watch'));
    await _pumpUntilVisible(tester, find.text('Watch Sources'));

    expect(find.text('Play'), findsOneWidget);
    await tester.ensureVisible(find.text('Play'));
    await tester.pump();
    await tester.tap(find.text('Play'));
    await tester.pump();
    await _pumpUntilVisible(tester, find.text('Choose File'));

    expect(find.text('Choose File'), findsOneWidget);
    expect(find.text('episode-01.mkv'), findsOneWidget);
  });

  testWidgets('App opens player after selecting a torrent file', (
    tester,
  ) async {
    await _pumpMockApp(tester);

    await tester.tap(find.text('Fullmetal Alchemist: Brotherhood'));
    await _pumpUntilVisible(tester, find.text('Anime Details'));

    await tester.ensureVisible(find.text('Watch'));
    await tester.pump();
    await tester.tap(find.text('Watch'));
    await _pumpUntilVisible(tester, find.text('Watch Sources'));

    await tester.ensureVisible(find.text('Play'));
    await tester.pump();
    await tester.tap(find.text('Play'));
    await _pumpUntilVisible(tester, find.text('Choose File'));

    await tester.tap(find.text('Watch File').first);
    await tester.pump();
    await _pumpUntilVisible(tester, find.text('Player'));

    expect(find.text('Player'), findsOneWidget);
    expect(find.byKey(const Key('mock_player_surface')), findsOneWidget);
  });
}
