import 'package:iris/features/watch_sources/domain/entities/watch_sources_tab.dart';

/// The tab the user chose last, for every anime: someone who watches only
/// torrents switches once.
abstract interface class WatchSourcesTabRepository {
  /// Null until the user has chosen.
  WatchSourcesTab? loadTab();

  Future<void> saveTab(WatchSourcesTab tab);
}
