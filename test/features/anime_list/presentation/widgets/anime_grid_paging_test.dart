import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_page_result.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_list_repository.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_state.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_card.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_grid.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';

void main() {
  testWidgets(
    'loads the next page near the end on desktop with ordered unique cards',
    (tester) async {
      setTestWindowSize(tester, TestWindowSizes.desktop);
      final pageTwo = Completer<AnimeListPageResult>();
      final repository = _PagingRepository(pageTwo: pageTwo);
      final bloc = AnimeListBloc(repository: repository)
        ..add(const AnimeListStarted());
      final controller = ScrollController();
      addTearDown(bloc.close);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _gridApp(bloc: bloc, controller: controller, viewportHeight: 950),
      );
      await _pumpFrames(tester);

      expect(repository.calls.map((query) => query.page), [1, 2]);
      expect(repository.calls.map((query) => query.limit), [12, 12]);
      expect(controller.position.maxScrollExtent, greaterThan(0));
      // The loading footer may increase the extent after prefetch starts.
      expect(bloc.state.items, hasLength(12));

      pageTwo.complete(_pageResult(2, hasMore: false));
      await tester.pumpAndSettle();

      final ids = bloc.state.items.map((item) => item.anime.id).toList();
      final visibleIds = tester
          .widgetList<AnimeCard>(find.byType(AnimeCard))
          .map((card) => card.item.anime.id)
          .toList();
      expect(ids, [
        ..._itemsForPage(1).map((item) => item.anime.id),
        ..._itemsForPage(2).map((item) => item.anime.id),
      ]);
      expect(ids.toSet(), hasLength(24));
      expect(visibleIds, ids.take(visibleIds.length));
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('Anime 2-12'), findsOneWidget);
      expect(repository.calls.map((query) => query.page), [1, 2]);
    },
  );

  testWidgets('repeated near-end scrolls do not overlap a pending page', (
    tester,
  ) async {
    setTestWindowSize(tester, TestWindowSizes.desktop);
    final pageTwo = Completer<AnimeListPageResult>();
    final repository = _PagingRepository(pageTwo: pageTwo);
    final bloc = AnimeListBloc(repository: repository)
      ..add(const AnimeListStarted());
    final controller = ScrollController();
    addTearDown(bloc.close);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _gridApp(bloc: bloc, controller: controller, viewportHeight: 950),
    );
    await _pumpFrames(tester);
    expect(bloc.state.isLoadingMore, isTrue);

    controller
      ..jumpTo(controller.position.maxScrollExtent)
      ..jumpTo(0)
      ..jumpTo(controller.position.maxScrollExtent);
    await _pumpFrames(tester);

    expect(repository.calls.map((query) => query.page), [1, 2]);

    pageTwo.complete(_pageResult(2, hasMore: false));
    await tester.pumpAndSettle();
  });

  testWidgets('a failed page waits for the footer retry', (tester) async {
    setTestWindowSize(tester, TestWindowSizes.phone);
    final repository = _PagingRepository(failPageTwoAttempts: 1);
    final bloc = AnimeListBloc(repository: repository)
      ..add(const AnimeListStarted());
    final controller = ScrollController();
    addTearDown(bloc.close);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_gridApp(bloc: bloc, controller: controller));
    await _pumpFrames(tester);
    expect(repository.calls.map((query) => query.page), [1]);

    bloc.add(const AnimeListNextPageRequested());
    await _pumpFrames(tester);
    expect(bloc.state.errorType, AnimeListErrorType.loadMore);
    expect(_pageTwoCalls(repository), 1);

    await tester.dragUntilVisible(
      find.text('Try Again'),
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(_pageTwoCalls(repository), 1);

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(_pageTwoCalls(repository), 2);
    expect(bloc.state.page, 2);
    expect(find.text('Anime 2-1'), findsOneWidget);
  });

  testWidgets('a resized hidden grid waits until it is visible to fill', (
    tester,
  ) async {
    setTestWindowSize(tester, TestWindowSizes.phone);
    final pageTwo = Completer<AnimeListPageResult>();
    final repository = _PagingRepository(pageTwo: pageTwo);
    final bloc = AnimeListBloc(repository: repository)
      ..add(const AnimeListStarted());
    final controller = ScrollController();
    addTearDown(bloc.close);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_gridApp(bloc: bloc, controller: controller));
    await _pumpFrames(tester);
    expect(repository.calls.map((query) => query.page), [1]);

    tester.view.physicalSize = TestWindowSizes.desktop;
    await tester.pumpWidget(
      _gridApp(bloc: bloc, controller: controller, tickerEnabled: false),
    );
    await _pumpFrames(tester);
    expect(repository.calls.map((query) => query.page), [1]);

    await tester.pumpWidget(
      _gridApp(bloc: bloc, controller: controller, tickerEnabled: true),
    );
    await _pumpFrames(tester);

    expect(repository.calls.map((query) => query.page), [1, 2]);
    expect(controller.position.maxScrollExtent, greaterThan(0));
    expect(controller.position.extentAfter, lessThanOrEqualTo(600));

    pageTwo.complete(_pageResult(2, hasMore: false));
    await tester.pumpAndSettle();
  });
}

Widget _gridApp({
  required AnimeListBloc bloc,
  required ScrollController controller,
  double? viewportHeight,
  bool tickerEnabled = true,
}) {
  return testApp(
    TickerMode(
      enabled: tickerEnabled,
      child: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: double.infinity,
            height: viewportHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return BlocProvider.value(
                  value: bloc,
                  child: BlocBuilder<AnimeListBloc, AnimeListState>(
                    builder: (context, state) => AnimeGrid(
                      bloc: bloc,
                      state: state,
                      columns: adaptiveColumnCount(
                        availableWidth: constraints.maxWidth,
                        minItemWidth: 150,
                        spacing: AnimeGrid.columnSpacing,
                        maxColumns: 8,
                      ),
                      controller: controller,
                      header: const SizedBox(height: 300),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester, {int count = 6}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump();
  }
}

int _pageTwoCalls(_PagingRepository repository) =>
    repository.calls.where((query) => query.page == 2).length;

class _PagingRepository implements AnimeListRepository {
  _PagingRepository({this.pageTwo, this.failPageTwoAttempts = 0});

  final Completer<AnimeListPageResult>? pageTwo;
  int failPageTwoAttempts;
  final List<AnimeListQuery> calls = [];

  @override
  Future<AnimeListPageResult> fetchAnimePage({
    required AnimeListQuery query,
  }) async {
    calls.add(query);
    if (query.page == 1) return _pageResult(1, hasMore: true);
    if (query.page == 2) {
      if (failPageTwoAttempts > 0) {
        failPageTwoAttempts--;
        throw StateError('Page two failed');
      }
      if (pageTwo != null) return pageTwo!.future;
    }
    return _pageResult(query.page, hasMore: false);
  }
}

AnimeListPageResult _pageResult(int page, {required bool hasMore}) =>
    AnimeListPageResult(
      items: _itemsForPage(page),
      page: page,
      hasMore: hasMore,
      query: '',
    );

List<AnimeListItem> _itemsForPage(int page) => [
  for (var index = 1; index <= AnimeListBloc.pageSize; index++)
    AnimeListItem(
      anime: AnimeSummary(
        id: '$page-$index',
        name: 'Anime $page-$index',
        russian: '',
        kind: 'tv',
        score: 8,
        status: 'released',
        episodes: 12,
        episodesAired: 12,
        airedOn: '2024-01-01',
        posterUrl: '',
      ),
    ),
];
