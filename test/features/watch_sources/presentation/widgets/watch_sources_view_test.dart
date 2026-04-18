import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_repository.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';
import 'package:iris/features/watch_sources/presentation/widgets/watch_sources_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('shows a loader while sources are loading', (tester) async {
    final cubit = WatchSourcesCubit(
      animeId: '52991',
      animeEnglishTitle: 'Frieren: Beyond Journey\'s End',
      repository: _PendingWatchSourcesRepository(),
    );

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows search, sorting and source cards when loading succeeds', (
    tester,
  ) async {
    final cubit = WatchSourcesCubit(
      animeId: '52991',
      animeEnglishTitle: 'Frieren: Beyond Journey\'s End',
      repository: const _SuccessWatchSourcesRepository(_items),
    );

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Search sources'), findsOneWidget);
    expect(find.text('Sort'), findsOneWidget);
    expect(find.text('[SubsPlease] Frieren - 28 (1080p)'), findsOneWidget);
    expect(find.text('[Judas] Frieren Season Pack Dual-Audio'), findsOneWidget);
    expect(find.text('Anime - English-translated'), findsWidgets);
    expect(find.text('Play'), findsWidgets);
  });

  testWidgets('filters cards by local title search', (tester) async {
    final cubit = WatchSourcesCubit(
      animeId: '52991',
      animeEnglishTitle: 'Frieren: Beyond Journey\'s End',
      repository: const _SuccessWatchSourcesRepository(_items),
    );

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Search sources'),
      'dual',
    );
    await tester.pumpAndSettle();

    expect(find.text('[Judas] Frieren Season Pack Dual-Audio'), findsOneWidget);
    expect(find.text('[SubsPlease] Frieren - 28 (1080p)'), findsNothing);
    expect(find.text('[ASW] Frieren - 27'), findsNothing);
  });

  testWidgets('shows dedicated empty state for local search results', (
    tester,
  ) async {
    final cubit = WatchSourcesCubit(
      animeId: '52991',
      animeEnglishTitle: 'Frieren: Beyond Journey\'s End',
      repository: const _SuccessWatchSourcesRepository(_items),
    );

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Search sources'),
      'nothing',
    );
    await tester.pumpAndSettle();

    expect(find.text('No watch sources match your search.'), findsOneWidget);
    expect(find.text('No watch sources found.'), findsNothing);
  });

  testWidgets('changes card order after selecting another sort option', (
    tester,
  ) async {
    final cubit = WatchSourcesCubit(
      animeId: '52991',
      animeEnglishTitle: 'Frieren: Beyond Journey\'s End',
      repository: const _SuccessWatchSourcesRepository(_items),
    );

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pumpAndSettle();

    expect(_topTitle(tester), '[SubsPlease] Frieren - 28 (1080p)');

    await tester.tap(find.text('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Apply'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(_topTitle(tester), '[ASW] Frieren - 27');
  });

  testWidgets('shows empty state when there are no results from repository', (
    tester,
  ) async {
    final cubit = WatchSourcesCubit(
      animeId: '52991',
      animeEnglishTitle: 'Unknown Title',
      repository: const _SuccessWatchSourcesRepository([]),
    );

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pumpAndSettle();

    expect(find.text('No watch sources found.'), findsOneWidget);
  });

  testWidgets('shows error state and retries loading', (tester) async {
    final repository = _ToggleWatchSourcesRepository();
    final cubit = WatchSourcesCubit(
      animeId: '52991',
      animeEnglishTitle: 'Frieren: Beyond Journey\'s End',
      repository: repository,
    );

    await _pumpView(tester, cubit: cubit..loadSources());
    await tester.pumpAndSettle();

    expect(find.text('Unable to load watch sources.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);

    repository.shouldFail = false;
    await tester.tap(find.text('Try Again'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('[SubsPlease] Frieren - 28 (1080p)'), findsOneWidget);
  });
}

Future<void> _pumpView(
  WidgetTester tester, {
  required WatchSourcesCubit cubit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: cubit,
        child: const Scaffold(body: WatchSourcesView()),
      ),
    ),
  );
}

String _topTitle(WidgetTester tester) {
  final titles = tester
      .widgetList<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.startsWith('['),
        ),
      )
      .map((widget) => widget.data!)
      .toList(growable: false);

  return titles.first;
}

class _PendingWatchSourcesRepository implements WatchSourcesRepository {
  @override
  Future<List<WatchSourceItem>> fetchSources(String animeEnglishTitle) {
    return Completer<List<WatchSourceItem>>().future;
  }
}

class _SuccessWatchSourcesRepository implements WatchSourcesRepository {
  const _SuccessWatchSourcesRepository(this.items);

  final List<WatchSourceItem> items;

  @override
  Future<List<WatchSourceItem>> fetchSources(String animeEnglishTitle) async {
    return items;
  }
}

class _ToggleWatchSourcesRepository implements WatchSourcesRepository {
  bool shouldFail = true;

  @override
  Future<List<WatchSourceItem>> fetchSources(String animeEnglishTitle) async {
    if (shouldFail) {
      throw Exception('First call fails');
    }

    return _items;
  }
}

const _items = [
  WatchSourceItem(
    title: '[ASW] Frieren - 27',
    category: 'Anime - English-translated',
    link: 'https://nyaa.si/view/3',
    torrent: 'https://nyaa.si/download/3.torrent',
    magnet: 'magnet:?xt=urn:btih:test-3',
    size: '900 MiB',
    time: '2026-04-01 09:30',
    seeders: 4,
    leechers: 1,
    downloads: 45,
  ),
  WatchSourceItem(
    title: '[SubsPlease] Frieren - 28 (1080p)',
    category: 'Anime - English-translated',
    link: 'https://nyaa.si/view/1',
    torrent: 'https://nyaa.si/download/1.torrent',
    magnet: 'magnet:?xt=urn:btih:test-1',
    size: '1.4 GiB',
    time: '2026-04-14 17:09',
    seeders: 33,
    leechers: 4,
    downloads: 269,
  ),
  WatchSourceItem(
    title: '[Judas] Frieren Season Pack Dual-Audio',
    category: 'Anime - English-translated',
    link: 'https://nyaa.si/view/2',
    torrent: 'https://nyaa.si/download/2.torrent',
    magnet: 'magnet:?xt=urn:btih:test-2',
    size: '7.2 GiB',
    time: '2026-04-15 12:00',
    seeders: 18,
    leechers: 2,
    downloads: 520,
  ),
];
