import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_repository.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_state.dart';
import 'package:iris/features/watch_sources/presentation/models/watch_sources_sort_option.dart';

import '../../watch_sources_test_doubles.dart';

void main() {
  test('emits loading then loaded with default sorting by seeders', () async {
    final cubit = frierenSourcesCubit(FixedWatchSourcesRepository());

    expectLater(
      cubit.stream,
      emitsInOrder([
        const WatchSourcesLoading(),
        WatchSourcesLoaded(
          allItems: frierenSources,
          visibleItems: [
            frierenMostSeededSource,
            frierenMostDownloadedSource,
            frierenOldSource,
          ],
          searchQuery: '',
          sortOption: WatchSourcesSortOption.seedersDesc,
        ),
      ]),
    );

    await cubit.loadSources();
  });

  test(
    'filters sources locally by title without additional repository calls',
    () async {
      final repository = FixedWatchSourcesRepository();
      final cubit = frierenSourcesCubit(repository);

      await cubit.loadSources();
      cubit.updateSearchQuery('dual');

      expect(repository.fetches, 1);
      expect(
        cubit.state,
        WatchSourcesLoaded(
          allItems: frierenSources,
          visibleItems: [frierenMostDownloadedSource],
          searchQuery: 'dual',
          sortOption: WatchSourcesSortOption.seedersDesc,
        ),
      );
    },
  );

  test('clearing search restores all items', () async {
    final cubit = frierenSourcesCubit(FixedWatchSourcesRepository());

    await cubit.loadSources();
    cubit
      ..updateSearchQuery('dual')
      ..updateSearchQuery('   ');

    expect(
      cubit.state,
      WatchSourcesLoaded(
        allItems: frierenSources,
        visibleItems: [
          frierenMostSeededSource,
          frierenMostDownloadedSource,
          frierenOldSource,
        ],
        searchQuery: '',
        sortOption: WatchSourcesSortOption.seedersDesc,
      ),
    );
  });

  test('updates visible items when sort option changes', () async {
    final cubit = frierenSourcesCubit(FixedWatchSourcesRepository());

    await cubit.loadSources();
    cubit.updateSortOption(WatchSourcesSortOption.titleAsc);

    expect(
      cubit.state,
      WatchSourcesLoaded(
        allItems: frierenSources,
        visibleItems: [
          frierenOldSource,
          frierenMostDownloadedSource,
          frierenMostSeededSource,
        ],
        searchQuery: '',
        sortOption: WatchSourcesSortOption.titleAsc,
      ),
    );
  });

  test('emits loading then empty when service returns no items', () async {
    final cubit = WatchSourcesCubit(
      animeId: '1',
      animeTitle: 'Unknown Title',
      searchTitles: ['Unknown Title'],
      repository: FixedWatchSourcesRepository([]),
    );

    expectLater(
      cubit.stream,
      emitsInOrder([const WatchSourcesLoading(), const WatchSourcesEmpty()]),
    );

    await cubit.loadSources();
  });

  test('emits failure when title is empty', () async {
    final cubit = WatchSourcesCubit(
      animeId: '1',
      animeTitle: '',
      searchTitles: const [],
      repository: FixedWatchSourcesRepository(),
    );

    expectLater(
      cubit.stream,
      emitsInOrder([const WatchSourcesLoading(), const WatchSourcesFailure()]),
    );

    await cubit.loadSources();
  });

  test('emits failure when repository throws', () async {
    final cubit = WatchSourcesCubit(
      animeId: '1535',
      animeTitle: 'Death Note',
      searchTitles: ['Death Note'],
      repository: _FailingWatchSourcesRepository(),
    );

    expectLater(
      cubit.stream,
      emitsInOrder([const WatchSourcesLoading(), const WatchSourcesFailure()]),
    );

    await cubit.loadSources();
  });

  for (final fails in [false, true]) {
    final outcome = fails ? 'the search fails' : 'the sources arrive';
    test('does not throw when closed before $outcome', () async {
      final pending = Completer<List<WatchSourceItem>>();
      final cubit = frierenSourcesCubit(
        PendingWatchSourcesRepository(pending.future),
      );

      final load = cubit.loadSources();
      await cubit.close();
      if (fails) {
        pending.completeError(Exception('Failed to load sources'));
      } else {
        pending.complete(frierenSources);
      }

      await expectLater(load, completes);
    });
  }
}

class _FailingWatchSourcesRepository implements WatchSourcesRepository {
  @override
  Future<List<WatchSourceItem>> fetchSources(List<String> titles) async {
    throw Exception('Failed to load sources');
  }
}
