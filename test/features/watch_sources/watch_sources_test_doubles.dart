import 'dart:async';

import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_sources_tab.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_repository.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_tab_repository.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';

const frierenOldSource = WatchSourceItem(
  title: '[ASW] Frieren - 27',
  magnet: 'magnet:?xt=urn:btih:test-3',
  size: '900 MiB',
  time: '2026-04-01 09:30',
  seeders: 4,
  downloads: 45,
);

const frierenMostSeededSource = WatchSourceItem(
  title: '[SubsPlease] Frieren - 28 (1080p)',
  magnet: 'magnet:?xt=urn:btih:test-1',
  size: '1.4 GiB',
  time: '2026-04-14 17:09',
  seeders: 33,
  downloads: 269,
);

const frierenMostDownloadedSource = WatchSourceItem(
  title: '[Judas] Frieren Season Pack Dual-Audio',
  magnet: 'magnet:?xt=urn:btih:test-2',
  size: '7.2 GiB',
  time: '2026-04-15 12:00',
  seeders: 18,
  downloads: 520,
);

/// Three Frieren releases in the order the tracker lists them.
const frierenSources = [
  frierenOldSource,
  frierenMostSeededSource,
  frierenMostDownloadedSource,
];

/// A [WatchSourcesCubit] that searches for Frieren in [repository].
WatchSourcesCubit frierenSourcesCubit(WatchSourcesRepository repository) {
  return WatchSourcesCubit(
    animeId: '52991',
    animeTitle: "Frieren: Beyond Journey's End",
    searchTitles: ["Frieren: Beyond Journey's End"],
    repository: repository,
  );
}

/// Answers every search with [items], counting the searches.
class FixedWatchSourcesRepository implements WatchSourcesRepository {
  FixedWatchSourcesRepository([this.items = frierenSources]);

  final List<WatchSourceItem> items;
  int fetches = 0;

  @override
  Future<List<WatchSourceItem>> fetchSources(List<String> titles) async {
    fetches++;
    return items;
  }
}

/// Answers every search with [answer], which by default never completes.
class PendingWatchSourcesRepository implements WatchSourcesRepository {
  PendingWatchSourcesRepository([Future<List<WatchSourceItem>>? answer])
    : answer = answer ?? Completer<List<WatchSourceItem>>().future;

  final Future<List<WatchSourceItem>> answer;

  @override
  Future<List<WatchSourceItem>> fetchSources(List<String> titles) => answer;
}

class MemoryWatchSourcesTabRepository implements WatchSourcesTabRepository {
  MemoryWatchSourcesTabRepository([this.tab]);

  WatchSourcesTab? tab;

  @override
  WatchSourcesTab? loadTab() => tab;

  @override
  Future<void> saveTab(WatchSourcesTab tab) async => this.tab = tab;
}
