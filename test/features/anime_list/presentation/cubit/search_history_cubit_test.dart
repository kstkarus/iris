import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/anime_list/data/repositories/shared_preferences_search_history_repository.dart';
import 'package:iris/features/anime_list/presentation/cubit/search_history_cubit.dart';
import 'package:iris/features/anime_list/domain/repositories/search_history_repository.dart';

void main() {
  test(
    'history is bounded, deduplicated, removable and survives recreation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesSearchHistoryRepository(preferences);
      final history = SearchHistoryCubit(repository: repository);
      history.record('  ');
      for (var i = 0; i < 12; i++) {
        history.record('query $i');
      }
      history.record(' QUERY 5 ');
      expect(history.state.length, 10);
      expect(history.state.first, 'QUERY 5');
      expect(
        history.state.where((q) => q.toLowerCase() == 'query 5').length,
        1,
      );
      history.remove('QUERY 5');
      await pumpEventQueue();
      final restored = SearchHistoryCubit(repository: repository);
      expect(restored.state, history.state);
      restored.clear();
      await pumpEventQueue();
      expect(repository.read(), isEmpty);
      await history.close();
      await restored.close();
    },
  );
  test('history remains usable when preferences cannot be written', () async {
    final history = SearchHistoryCubit(repository: _FailingHistory());
    history.record('query');
    await pumpEventQueue();
    expect(history.state, ['query']);
    history.clear();
    await pumpEventQueue();
    expect(history.state, isEmpty);
    await history.close();
  });
}

class _FailingHistory implements SearchHistoryRepository {
  @override
  List<String> read() => const [];
  @override
  Future<void> save(List<String> queries) async =>
      throw StateError('disk unavailable');
}
