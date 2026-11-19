import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/anime_details/presentation/widgets/recently_watched_section.dart';

import '../../../../helpers/fake_watch_progress_repository.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';

WatchProgress _progress(
  String torrentKey, {
  String animeId = '5114',
  int fileIndex = 0,
  int minute = 0,
  int seconds = 300,
}) {
  return WatchProgress(
    torrentKey: torrentKey,
    fileIndex: fileIndex,
    fileName: 'ep-0${fileIndex + 1}.mkv',
    magnet: 'magnet:?xt=urn:btih:$torrentKey',
    sourceTitle: 'Release $torrentKey',
    position: Duration(seconds: seconds),
    duration: const Duration(minutes: 24),
    updatedAt: DateTime.utc(2026, 10, 4, 12, minute),
    animeId: animeId,
    animeTitle: 'Anime $animeId',
  );
}

void main() {
  Future<WatchProgressCubit> pump(
    WidgetTester tester,
    List<WatchProgress> items,
  ) async {
    final cubit = WatchProgressCubit(
      repository: FixedWatchProgressRepository(items),
    )..load();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        BlocProvider.value(
          value: cubit,
          child: const Scaffold(
            body: SingleChildScrollView(
              child: RecentlyWatchedSection(animeId: '5114'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('lists the latest file of each source used for this anime', (
    tester,
  ) async {
    await pump(tester, [
      _progress('aaa', fileIndex: 0, minute: 1),
      _progress('aaa', fileIndex: 1, minute: 3),
      _progress('bbb', minute: 2),
      _progress('ccc', animeId: '999', minute: 4),
    ]);

    expect(find.text('Recently watched'), findsOneWidget);
    expect(find.text('Release aaa'), findsOneWidget);
    expect(find.text('Last watched: ep-02'), findsOneWidget);
    expect(find.text('Release bbb'), findsOneWidget);
    expect(find.text('Release ccc'), findsNothing);
  });

  testWidgets('the button says what it will do', (tester) async {
    await pump(tester, [
      _progress('aaa', minute: 3),
      // Opened for a few seconds: playback starts from the beginning.
      _progress('bbb', minute: 2, seconds: 4),
      _progress('ccc', minute: 1, seconds: 23 * 60),
    ]);

    String label(String torrent) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(ValueKey('recently_watched_$torrent')),
            matching: find.descendant(
              of: find.byType(OutlinedButton),
              matching: find.byType(Text),
            ),
          ),
        )
        .data!;
    expect(label('aaa'), 'Continue');
    expect(label('bbb'), 'Watch');
    expect(label('ccc'), 'Play next');
  });

  testWidgets('the watched label keeps its leading edge as progress shrinks', (
    tester,
  ) async {
    setTestWindowSize(tester, TestWindowSizes.phone);
    final cubit = await pump(tester, [_progress('aaa')]);
    cubit.emit([_progress('aaa', seconds: 23 * 60)]);
    await tester.pump();
    await tester.pump();

    final watched = find.text('Watched');
    final start = tester.getTopLeft(watched).dx;
    for (var frame = 0; frame < 18; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.getTopLeft(watched).dx, closeTo(start, 0.01));
    }
  });
}
