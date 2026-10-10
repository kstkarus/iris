import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/watch_sources/data/repositories/shared_preferences_watch_sources_tab_repository.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_sources_tab.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_tab_cubit.dart';

void main() {
  Future<SharedPreferencesWatchSourcesTabRepository> repository([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferencesWatchSourcesTabRepository(
      await SharedPreferences.getInstance(),
    );
  }

  test('opens on online until the user chooses', () async {
    final cubit = WatchSourcesTabCubit(repository: await repository());
    addTearDown(cubit.close);

    expect(cubit.state, WatchSourcesTab.online);
  });

  test('a chosen tab is the next page\'s', () async {
    final tabs = await repository();
    final cubit = WatchSourcesTabCubit(repository: tabs);
    addTearDown(cubit.close);

    await cubit.select(WatchSourcesTab.torrents);

    expect(cubit.state, WatchSourcesTab.torrents);
    final next = WatchSourcesTabCubit(repository: tabs);
    addTearDown(next.close);
    expect(next.state, WatchSourcesTab.torrents);
  });

  test('a stored name it does not know is no choice', () async {
    final tabs = await repository({'watch_sources.tab': 'downloads'});

    expect(tabs.loadTab(), isNull);
  });
}
