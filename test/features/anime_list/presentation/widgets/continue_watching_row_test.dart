import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/anime_list/presentation/widgets/continue_watching_row.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';

void main() {
  test('changing a torrent keeps one continuation for the same anime', () {
    final items = continueWatchingItems([
      _progress('old', seconds: 700, minute: 10),
      WatchProgress(
        torrentKey: 'new',
        fileIndex: 0,
        fileName: 'episode.mkv',
        magnet: 'm',
        sourceTitle: 'Release',
        animeId: _progress('old', seconds: 700, minute: 10).animeId,
        animeTitle: 'Anime',
        position: const Duration(minutes: 10),
        duration: const Duration(minutes: 24),
        updatedAt: DateTime.utc(2026, 10, 7, 12, 20),
      ),
    ]);
    expect(items, hasLength(1));
    expect(items.single.torrentKey, 'new');
  });

  test('leaves out files only looked at, keeping the one being watched', () {
    final items = continueWatchingItems([
      // A glance at the next episode after watching the previous one.
      _progress('a', file: 1, seconds: 5, minute: 30),
      _progress('a', file: 0, seconds: 700, minute: 20),
      _progress('b', seconds: 40, minute: 10),
    ]);

    expect(items.map((item) => (item.torrentKey, item.fileIndex)), [('a', 0)]);
  });

  test(
    'keeps the newest entry per anime and unlinked source when not hidden',
    () {
      final resumed = _progress('pack', animeId: 'a', seconds: 700, minute: 30);
      final olderHidden = _progress(
        'pack',
        animeId: 'a',
        file: 3,
        seconds: 700,
        minute: 10,
      ).copyWith(hiddenFromContinueWatching: true);
      final second = _progress(
        'pack',
        animeId: 'b',
        file: 1,
        seconds: 700,
        minute: 20,
      );
      final unlinked = _progress(
        'pack',
        animeId: '',
        file: 2,
        seconds: 700,
        minute: 15,
      );
      final dismissedOlder = _progress(
        'pack',
        animeId: 'c',
        file: 4,
        seconds: 700,
        minute: 12,
      );
      final dismissedNewer = _progress(
        'pack',
        animeId: 'c',
        file: 5,
        seconds: 700,
        minute: 25,
      ).copyWith(hiddenFromContinueWatching: true);
      expect(
        continueWatchingItems([
          olderHidden,
          unlinked,
          second,
          resumed,
          dismissedOlder,
          dismissedNewer,
        ]),
        [resumed, second, unlinked],
      );
    },
  );

  testWidgets('shows all five compact entries and opens the selected one', (
    tester,
  ) async {
    setTestWindowSize(tester, const Size(1280, 1600));
    final items = [
      for (var index = 0; index < 5; index++)
        _progress('t$index', seconds: 600 + index * 60, minute: 50 - index),
    ];

    WatchProgress? selected;
    await tester.pumpWidget(
      _app(
        ContinueWatchingRow(
          items: items,
          onOpen: (item) => selected = item,
          onOpenAnime: (_) {},
          onRemove: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('continue_watching_anime:t1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('continue_watching_anime:t2')),
      findsOneWidget,
    );
    // The list already says what the times are.
    expect(find.text('11:00 / 24:00'), findsOneWidget);

    expect(
      find.byKey(const ValueKey('continue_watching_anime:t4')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('continue_watching_anime:t2')));
    expect(selected, items[2]);
  });

  testWidgets('marks a finished entry instead of showing unfinished times', (
    tester,
  ) async {
    setTestWindowSize(tester, const Size(1280, 1200));

    await tester.pumpWidget(
      _app(
        ContinueWatchingRow(
          items: [
            for (var index = 0; index < 3; index++)
              _progress(
                't$index',
                seconds: index == 0 ? 1440 : 600,
                minute: 50 - index,
              ),
          ],
          onOpen: (_) {},
          onOpenAnime: (_) {},
          onRemove: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('continue_watching_anime:t2')),
      findsOneWidget,
    );
    expect(find.text('Watched'), findsOneWidget);
    expect(find.text('24:00 / 24:00'), findsNothing);
  });

  testWidgets('dissolves removed entry before removing it from layout', (
    tester,
  ) async {
    setTestWindowSize(tester, const Size(1280, 1200));
    final initial = [
      _progress('a', seconds: 600, minute: 20),
      _progress('b', seconds: 600, minute: 10),
    ];

    Widget buildRow(
      List<WatchProgress> items, {
      bool disableAnimations = false,
    }) {
      final app = _app(
        ContinueWatchingRow(
          items: items,
          onOpen: (_) {},
          onOpenAnime: (_) {},
          onRemove: (_) {},
        ),
      );
      return disableAnimations
          ? MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: app,
            )
          : app;
    }

    await tester.pumpWidget(buildRow(initial));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('continue_watching_anime:a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('continue_watching_anime:b')),
      findsOneWidget,
    );

    await tester.pumpWidget(buildRow([initial[1]]));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('continue_watching_anime:a')),
      findsOneWidget,
    );

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('continue_watching_anime:a')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('continue_watching_anime:b')),
      findsOneWidget,
    );

    // With reduced motion, removal finishes after a single post-frame step.
    await tester.pumpWidget(buildRow(initial, disableAnimations: true));
    await tester.pump();
    await tester.pumpWidget(buildRow([initial[1]], disableAnimations: true));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('continue_watching_anime:a')),
      findsNothing,
    );
  });
}

Widget _app(Widget child) {
  return testApp(Scaffold(body: SingleChildScrollView(child: child)));
}

WatchProgress _progress(
  String torrent, {
  String? animeId,
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
    animeId: animeId ?? torrent,
    animeTitle: 'Anime $torrent',
  );
}
