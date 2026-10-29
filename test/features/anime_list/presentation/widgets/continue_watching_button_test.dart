import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/app/theme/app_theme.dart';
import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress_repository.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_page_result.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_list_repository.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_search_bloc.dart';
import 'package:iris/features/anime_list/presentation/pages/anime_list_page.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_grid.dart';
import 'package:iris/features/anime_list/presentation/widgets/continue_watching_button.dart';
import 'package:iris/features/anime_list/presentation/widgets/continue_watching_row.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/search_field.dart';
import 'package:iris/shared/widgets/search_toolbar.dart';

import '../../../../helpers/test_window.dart';

void main() {
  for (final size in [const Size(1280, 900), const Size(390, 844)]) {
    for (final finished in [false, true]) {
      testWidgets('opens the same resume target at $size, finished=$finished', (
        tester,
      ) async {
        final harness = await _pump(
          tester,
          size,
          items: [_progress(finished: finished)],
        );
        expect(find.byType(ContinueWatchingRow), findsNothing);
        final grid = tester.getRect(find.byType(AnimeGrid));
        await tester.tap(find.byKey(ContinueWatchingButton.buttonKey));
        await tester.pumpAndSettle();
        expect(
          find.text(finished ? 'Watched' : '12:00 / 24:00'),
          findsOneWidget,
        );
        if (size.width >= 600) {
          expect(tester.getRect(find.byType(AnimeGrid)), grid);
        }
        await tester.tap(
          find.byKey(const ValueKey('continue_watching_source')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Player destination'), findsOneWidget);
        expect(find.byType(ContinueWatchingRow), findsNothing);
        final args = harness.opened.single;
        expect(args.magnet, 'magnet:source');
        expect(args.autoOpenFileIndex, finished ? isNull : 2);
        expect(args.preferDownloads, isTrue);
      });
    }

    testWidgets('removing the last entry closes its overlay at $size', (
      tester,
    ) async {
      final harness = await _pump(tester, size);
      await tester.tap(find.byKey(ContinueWatchingButton.buttonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from list'));
      await tester.pumpAndSettle();
      expect(harness.history.items, isEmpty);
      expect(find.byType(ContinueWatchingRow), findsNothing);
      expect(find.byKey(ContinueWatchingButton.buttonKey), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'history remains available during search without replacing its controls',
    (tester) async {
      await _pump(tester, const Size(390, 844));
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      final query = field.controller;
      expect(find.byKey(SearchToolbar.cancelButtonKey), findsOneWidget);
      expect(find.byKey(SearchField.clearButtonKey), findsOneWidget);
      expect(find.byTooltip('Filter & Sort'), findsOneWidget);
      expect(find.byKey(ContinueWatchingButton.buttonKey), findsOneWidget);
      await tester.tap(find.byKey(ContinueWatchingButton.buttonKey));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller,
        same(query),
      );
      expect(query!.text, 'test');
      expect(find.byKey(SearchToolbar.cancelButtonKey), findsOneWidget);
      await tester.tap(find.byKey(SearchField.clearButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SearchToolbar.cancelButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('Popular'), findsOneWidget);
      expect(find.byKey(ContinueWatchingButton.buttonKey), findsOneWidget);
    },
  );

  testWidgets('Escape closes the desktop overlay before leaving search', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 900));
    await tester.enterText(find.byType(TextField), 'test');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ContinueWatchingButton.buttonKey));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ContinueWatchingRow), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'test',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('a narrow large-text phone can search and scroll all history', (
    tester,
  ) async {
    await _pump(
      tester,
      const Size(320, 640),
      textScale: 2,
      items: [for (var i = 0; i < 5; i++) _progress(source: 'source$i')],
    );
    await tester.enterText(find.byType(TextField), 'test');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(ContinueWatchingButton.buttonKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('continue_watching_source4')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Future<({List<AnimePlayerSourceArgs> opened, _History history})> _pump(
  WidgetTester tester,
  Size size, {
  List<WatchProgress>? items,
  double textScale = 1,
}) async {
  setTestWindowSize(tester, size);
  final history = _History(items ?? [_progress()]);
  final cubit = WatchProgressCubit(repository: history)..load();
  final catalog = AnimeListBloc(repository: _Catalog())
    ..add(const AnimeListStarted());
  final search = AnimeSearchBloc(repository: _Catalog());
  final opened = <AnimePlayerSourceArgs>[];
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const AnimeListPage()),
      GoRoute(
        path: '/play',
        name: 'torrent-stream-files',
        builder: (_, state) {
          opened.add(state.extra! as AnimePlayerSourceArgs);
          return const Scaffold(body: Text('Player destination'));
        },
      ),
    ],
  );
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: cubit),
        BlocProvider.value(value: catalog),
        BlocProvider.value(value: search),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(brightness: Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    await Future.wait([cubit.close(), catalog.close(), search.close()]);
    await history.changes.close();
  });
  return (opened: opened, history: history);
}

WatchProgress _progress({bool finished = false, String source = 'source'}) =>
    WatchProgress(
      torrentKey: source,
      fileIndex: 2,
      fileName: 'Episode 3.mkv',
      magnet: 'magnet:$source',
      sourceTitle: 'Release',
      animeId: source,
      animeTitle: 'An exceptionally long anime title to check wrapping',
      position: Duration(minutes: finished ? 24 : 12),
      duration: const Duration(minutes: 24),
      updatedAt: DateTime(2026),
    );

class _History implements WatchProgressRepository {
  _History(this.items);
  List<WatchProgress> items;
  late final StreamController<List<WatchProgress>> changes =
      StreamController<List<WatchProgress>>.broadcast(
        onListen: () => changes.add(items),
      );
  @override
  Stream<List<WatchProgress>> watchAll() => changes.stream;

  @override
  Future<void> removeTorrent({required String torrentKey}) async {
    items = items.where((item) => item.torrentKey != torrentKey).toList();
    changes.add(items);
  }

  @override
  Future<void> save(WatchProgress progress) async {}
  @override
  Future<WatchProgress?> find({
    required String torrentKey,
    required int fileIndex,
  }) async => null;
}

class _Catalog implements AnimeListRepository {
  @override
  Future<AnimeListPageResult> fetchAnimePage({
    required AnimeListQuery query,
  }) async => AnimeListPageResult(
    page: query.page,
    query: query.search,
    hasMore: false,
    items: [
      for (var i = 0; i < 12; i++)
        AnimeListItem(
          anime: AnimeSummary(
            id: '$i',
            name: 'Catalog $i',
            russian: '',
            kind: 'tv',
            score: 8,
            status: 'released',
            episodes: 12,
            episodesAired: 12,
            airedOn: '2024',
            posterUrl: '',
          ),
        ),
    ],
  );
}
