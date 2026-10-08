import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_repository.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_state.dart';
import 'package:iris/features/watch_sources/presentation/models/watch_sources_sort_option.dart';

void main() {
  test('emits loading then loaded with default sorting by seeders', () async {
    final cubit = WatchSourcesCubit(
      animeId: '52991',
      animeTitle: 'Frieren: Beyond Journey\'s End',
      searchTitles: ['Frieren: Beyond Journey\'s End'],
      repository: _SuccessWatchSourcesRepository(_items),
    );

    expectLater(
      cubit.stream,
      emitsInOrder([
        const WatchSourcesLoading(),
        WatchSourcesLoaded(
          allItems: _items,
          visibleItems: [
            _itemWithMostSeeders,
            _itemWithMostDownloads,
            _itemOld,
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
      final repository = _CountingWatchSourcesRepository(_items);
      final cubit = WatchSourcesCubit(
        animeId: '52991',
        animeTitle: 'Frieren: Beyond Journey\'s End',
        searchTitles: ['Frieren: Beyond Journey\'s End'],
        repository: repository,
      );

      await cubit.loadSources();
      cubit.updateSearchQuery('dual');

      expect(repository.callCount, 1);
      expect(
        cubit.state,
        WatchSourcesLoaded(
          allItems: _items,
          visibleItems: [_itemWithMostDownloads],
          searchQuery: 'dual',
          sortOption: WatchSourcesSortOption.seedersDesc,
        ),
      );
    },
  );

  test('clearing search restores all items', () async {
    final cubit = WatchSourcesCubit(
      animeId: '52991',
      animeTitle: 'Frieren: Beyond Journey\'s End',
      searchTitles: ['Frieren: Beyond Journey\'s End'],
      repository: _SuccessWatchSourcesRepository(_items),
    );

    await cubit.loadSources();
    cubit
      ..updateSearchQuery('dual')
      ..updateSearchQuery('   ');

    expect(
      cubit.state,
      WatchSourcesLoaded(
        allItems: _items,
        visibleItems: [_itemWithMostSeeders, _itemWithMostDownloads, _itemOld],
        searchQuery: '',
        sortOption: WatchSourcesSortOption.seedersDesc,
      ),
    );
  });

  test('updates visible items when sort option changes', () async {
    final cubit = WatchSourcesCubit(
      animeId: '52991',
      animeTitle: 'Frieren: Beyond Journey\'s End',
      searchTitles: ['Frieren: Beyond Journey\'s End'],
      repository: _SuccessWatchSourcesRepository(_items),
    );

    await cubit.loadSources();
    cubit.updateSortOption(WatchSourcesSortOption.titleAsc);

    expect(
      cubit.state,
      WatchSourcesLoaded(
        allItems: _items,
        visibleItems: [_itemOld, _itemWithMostDownloads, _itemWithMostSeeders],
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
      repository: const _SuccessWatchSourcesRepository([]),
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
      repository: const _SuccessWatchSourcesRepository(_items),
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

  test('does not throw when closed before the sources arrive', () async {
    final pending = Completer<List<WatchSourceItem>>();
    final cubit = WatchSourcesCubit(
      animeId: '52991',
      animeTitle: 'Frieren: Beyond Journey\'s End',
      searchTitles: ['Frieren: Beyond Journey\'s End'],
      repository: _PendingWatchSourcesRepository(pending.future),
    );

    final load = cubit.loadSources();
    await cubit.close();
    pending.complete(_items);

    await expectLater(load, completes);
  });

  test('does not throw when closed before the search fails', () async {
    final pending = Completer<List<WatchSourceItem>>();
    final cubit = WatchSourcesCubit(
      animeId: '52991',
      animeTitle: 'Frieren: Beyond Journey\'s End',
      searchTitles: ['Frieren: Beyond Journey\'s End'],
      repository: _PendingWatchSourcesRepository(pending.future),
    );

    final load = cubit.loadSources();
    await cubit.close();
    pending.completeError(Exception('Failed to load sources'));

    await expectLater(load, completes);
  });
}

class _SuccessWatchSourcesRepository implements WatchSourcesRepository {
  const _SuccessWatchSourcesRepository(this.items);

  final List<WatchSourceItem> items;

  @override
  Future<List<WatchSourceItem>> fetchSources(List<String> titles) async {
    return items;
  }
}

class _CountingWatchSourcesRepository implements WatchSourcesRepository {
  _CountingWatchSourcesRepository(this.items);

  final List<WatchSourceItem> items;
  int callCount = 0;

  @override
  Future<List<WatchSourceItem>> fetchSources(List<String> titles) async {
    callCount += 1;
    return items;
  }
}

class _FailingWatchSourcesRepository implements WatchSourcesRepository {
  @override
  Future<List<WatchSourceItem>> fetchSources(List<String> titles) async {
    throw Exception('Failed to load sources');
  }
}

class _PendingWatchSourcesRepository implements WatchSourcesRepository {
  const _PendingWatchSourcesRepository(this.pending);

  final Future<List<WatchSourceItem>> pending;

  @override
  Future<List<WatchSourceItem>> fetchSources(List<String> titles) => pending;
}

const _itemWithMostSeeders = WatchSourceItem(
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
);

const _itemWithMostDownloads = WatchSourceItem(
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
);

const _itemOld = WatchSourceItem(
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
);

const _items = [_itemOld, _itemWithMostSeeders, _itemWithMostDownloads];
