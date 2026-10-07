import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress_repository.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/anime_details/presentation/widgets/recently_watched_section.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

WatchProgress _progress(
  String torrentKey, {
  String animeId = '5114',
  int fileIndex = 0,
  int minute = 0,
}) {
  return WatchProgress(
    torrentKey: torrentKey,
    fileIndex: fileIndex,
    fileName: 'ep-0${fileIndex + 1}.mkv',
    magnet: 'magnet:?xt=urn:btih:$torrentKey',
    sourceTitle: 'Release $torrentKey',
    position: const Duration(minutes: 5),
    duration: const Duration(minutes: 24),
    updatedAt: DateTime.utc(2026, 10, 4, 12, minute),
    animeId: animeId,
    animeTitle: 'Anime $animeId',
  );
}

void main() {
  Future<void> pump(WidgetTester tester, List<WatchProgress> items) async {
    final cubit = WatchProgressCubit(
      repository: _StubWatchProgressRepository(items),
    )..load();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
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

    expect(find.text('RECENTLY WATCHED'), findsOneWidget);
    expect(find.text('Release aaa'), findsOneWidget);
    expect(find.text('Last watched: ep-02'), findsOneWidget);
    expect(find.text('Release bbb'), findsOneWidget);
    expect(find.text('Release ccc'), findsNothing);
  });

  testWidgets('stays hidden without history for this anime', (tester) async {
    await pump(tester, [_progress('ccc', animeId: '999')]);

    expect(find.text('RECENTLY WATCHED'), findsNothing);
  });
}

class _StubWatchProgressRepository implements WatchProgressRepository {
  const _StubWatchProgressRepository(this.items);

  final List<WatchProgress> items;

  @override
  Stream<List<WatchProgress>> watchAll() => Stream.value(items);

  @override
  Future<WatchProgress?> find({
    required String torrentKey,
    required int fileIndex,
  }) async => null;

  @override
  Future<void> save(WatchProgress progress) async {}

  @override
  Future<void> removeTorrent({required String torrentKey}) async {}
}
