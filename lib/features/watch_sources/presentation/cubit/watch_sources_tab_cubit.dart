import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/watch_sources/domain/entities/watch_sources_tab.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_tab_repository.dart';

/// The tab the user chose, online the first time. The page shows another
/// one only when the chosen one has nothing, and does not remember that.
class WatchSourcesTabCubit extends Cubit<WatchSourcesTab> {
  WatchSourcesTabCubit({required WatchSourcesTabRepository repository})
    : _repository = repository,
      super(repository.loadTab() ?? WatchSourcesTab.online);

  final WatchSourcesTabRepository _repository;

  Future<void> select(WatchSourcesTab tab) async {
    if (tab == state) return;
    emit(tab);
    await _repository.saveTab(tab);
  }
}
