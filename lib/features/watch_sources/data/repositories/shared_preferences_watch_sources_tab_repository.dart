import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/watch_sources/domain/entities/watch_sources_tab.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_tab_repository.dart';

class SharedPreferencesWatchSourcesTabRepository
    implements WatchSourcesTabRepository {
  SharedPreferencesWatchSourcesTabRepository(this._preferences);

  static const _storageKey = 'watch_sources.tab';

  final SharedPreferences _preferences;

  @override
  WatchSourcesTab? loadTab() {
    final name = _preferences.getString(_storageKey);
    for (final tab in WatchSourcesTab.values) {
      if (tab.name == name) return tab;
    }
    return null;
  }

  @override
  Future<void> saveTab(WatchSourcesTab tab) =>
      _preferences.setString(_storageKey, tab.name);
}
