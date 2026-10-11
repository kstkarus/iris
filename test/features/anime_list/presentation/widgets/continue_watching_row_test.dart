import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/anime_list/presentation/widgets/continue_watching_row.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';

void main() {
  test('leaves out files only looked at, keeping the one being watched', () {
    final items = continueWatchingItems([
      // A glance at the next episode after watching the previous one.
      _progress('a', file: 1, seconds: 5, minute: 30),
      _progress('a', file: 0, seconds: 700, minute: 20),
      _progress('b', seconds: 40, minute: 10),
    ]);

    expect(items.map((item) => (item.torrentKey, item.fileIndex)), [('a', 0)]);
  });

  testWidgets('folds the rows after the first one under a toggle', (
    tester,
  ) async {
    setTestWindowSize(tester, const Size(1280, 1600));
    final items = [
      for (var index = 0; index < 5; index++)
        _progress('t$index', seconds: 600 + index * 60, minute: 50 - index),
    ];

    await tester.pumpWidget(_app(ContinueWatchingRow(items: items)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('continue_watching_t1')), findsOneWidget);
    expect(find.byKey(const ValueKey('continue_watching_t2')), findsNothing);
    // The list already says what the times are.
    expect(find.text('11:00 / 24:00'), findsOneWidget);

    await tester.tap(find.text('3 more'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('continue_watching_t4')), findsOneWidget);

    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('continue_watching_t2')), findsNothing);
  });

  testWidgets('shows a single extra row instead of folding it', (tester) async {
    setTestWindowSize(tester, const Size(1280, 1200));

    await tester.pumpWidget(
      _app(
        ContinueWatchingRow(
          items: [
            for (var index = 0; index < 3; index++)
              _progress('t$index', seconds: 600, minute: 50 - index),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('continue_watching_more')), findsNothing);
    expect(find.byKey(const ValueKey('continue_watching_t2')), findsOneWidget);
  });
}

Widget _app(Widget child) {
  return testApp(Scaffold(body: SingleChildScrollView(child: child)));
}

WatchProgress _progress(
  String torrent, {
  int file = 0,
  required int seconds,
  required int minute,
}) {
  return WatchProgress(
    torrentKey: torrent,
    fileIndex: file,
    fileName: 'Episode $file.mkv',
    magnet: 'magnet:?xt=urn:btih:$torrent',
    sourceTitle: 'Release $torrent',
    position: Duration(seconds: seconds),
    duration: const Duration(minutes: 24),
    updatedAt: DateTime.utc(2026, 10, 7, 12, minute),
    animeId: torrent,
    animeTitle: 'Anime $torrent',
  );
}
