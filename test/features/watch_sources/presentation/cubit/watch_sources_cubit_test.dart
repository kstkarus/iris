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

  test('reads decimal and binary sizes with either decimal separator', () {
    const sizes = {
      '1.4 GiB': 1.4 * (1 << 30),
      '850 MiB': 850 * (1 << 20),
      ' 12,3 gb ': 12300000000,
      '512 MB': 512000000,
      '400 kIb': 400 * (1 << 10),
      '1024 B': 1024,
      '0 B': 0,
    };
    for (final MapEntry(key: label, value: bytes) in sizes.entries) {
      expect(_sizedSource('Release', label).sizeInBytes, bytes, reason: label);
    }
    for (final label in ['', 'unknown', '42 XB', '-1 GB', '1,2.3 MiB', '10']) {
      expect(_sizedSource('Release', label).sizeInBytes, isNull, reason: label);
    }
  });

  test('sorts by byte count, with unavailable sizes last', () async {
    final items = [
      _sizedSource('Z binary', '850 MiB'),
      _sizedSource('A bad size', 'unknown'),
      _sizedSource('A decimal', '850 MB'),
      _sizedSource('B empty size', ''),
      _sizedSource('Z empty file', '0 B'),
      _sizedSource('Z tied', '1 KiB'),
      _sizedSource('A tied', '1024 B'),
      _sizedSource('Largest', '1,4 GiB'),
    ];
    final cubit = frierenSourcesCubit(FixedWatchSourcesRepository(items));
    addTearDown(cubit.close);

    await cubit.loadSources();
    cubit.updateSortOption(WatchSourcesSortOption.sizeDesc);

    expect((cubit.state as WatchSourcesLoaded).visibleItems, [
      items[7],
      items[0],
      items[2],
      items[6],
      items[5],
      items[4],
      items[1],
      items[3],
    ]);
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

WatchSourceItem _sizedSource(String title, String size) => WatchSourceItem(
  title: title,
  magnet: 'magnet:?xt=urn:btih:test',
  size: size,
  time: '',
  seeders: 0,
  downloads: 0,
);

class _FailingWatchSourcesRepository implements WatchSourcesRepository {
  @override
  Future<List<WatchSourceItem>> fetchSources(List<String> titles) async {
    throw Exception('Failed to load sources');
  }
}
