import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/anime_list/domain/repositories/search_history_repository.dart';

class SharedPreferencesSearchHistoryRepository
    implements SearchHistoryRepository {
  const SharedPreferencesSearchHistoryRepository(this._preferences);

  static const key = 'catalog_recent_searches';
  final SharedPreferences _preferences;

  @override
  List<String> read() => _preferences.getStringList(key) ?? const [];

  @override
  Future<void> save(List<String> queries) async {
    if (!await _preferences.setStringList(key, queries)) {
      throw StateError('Could not save recent searches');
    }
  }
}
