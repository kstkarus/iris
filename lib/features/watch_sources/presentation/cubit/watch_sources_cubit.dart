import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/anime/domain/anime_titles.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_repository.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_state.dart';
import 'package:iris/features/watch_sources/presentation/models/watch_sources_sort_option.dart';

class WatchSourcesCubit extends Cubit<WatchSourcesState> {
  WatchSourcesCubit({
    required this.animeId,
    required this.animeTitles,
    required this.searchTitles,
    required WatchSourcesRepository repository,
  }) : _repository = repository,
       super(const WatchSourcesInitial());

  final String animeId;

  final AnimeTitles animeTitles;

  /// What releases are searched by.
  final List<String> searchTitles;
  final WatchSourcesRepository _repository;

  Future<void> loadSources() async {
    emit(const WatchSourcesLoading());

    if (searchTitles.isEmpty) {
      emit(const WatchSourcesFailure());
      return;
    }

    try {
      final items = await _repository.fetchSources(searchTitles);
      if (isClosed) return;

      if (items.isEmpty) {
        emit(const WatchSourcesEmpty());
        return;
      }

      emit(
        _buildLoadedState(
          allItems: items,
          searchQuery: '',
          sortOption: WatchSourcesSortOption.seedersDesc,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(const WatchSourcesFailure());
    }
  }

  void updateSearchQuery(String query) {
    final currentState = state;
    if (currentState is! WatchSourcesLoaded) {
      return;
    }

    emit(
      _buildLoadedState(
        allItems: currentState.allItems,
        searchQuery: query.trim(),
        sortOption: currentState.sortOption,
      ),
    );
  }

  void updateSortOption(WatchSourcesSortOption option) {
    final currentState = state;
    if (currentState is! WatchSourcesLoaded) {
      return;
    }

    emit(
      _buildLoadedState(
        allItems: currentState.allItems,
        searchQuery: currentState.searchQuery,
        sortOption: option,
      ),
    );
  }

  WatchSourcesLoaded _buildLoadedState({
    required List<WatchSourceItem> allItems,
    required String searchQuery,
    required WatchSourcesSortOption sortOption,
  }) {
    final visibleItems = _applyPresentationState(
      items: allItems,
      searchQuery: searchQuery,
      sortOption: sortOption,
    );

    return WatchSourcesLoaded(
      allItems: List.unmodifiable(allItems),
      visibleItems: List.unmodifiable(visibleItems),
      searchQuery: searchQuery,
      sortOption: sortOption,
    );
  }
}

List<WatchSourceItem> _applyPresentationState({
  required List<WatchSourceItem> items,
  required String searchQuery,
  required WatchSourcesSortOption sortOption,
}) {
  final normalizedQuery = searchQuery.toLowerCase();
  final filtered = items.where((item) {
    if (normalizedQuery.isEmpty) {
      return true;
    }

    return item.title.toLowerCase().contains(normalizedQuery);
  }).toList();

  final sizes = {
    if (sortOption == WatchSourcesSortOption.sizeDesc)
      for (final item in filtered) item.size: item.sizeInBytes,
  };
  filtered.sort((left, right) {
    final byOption = switch (sortOption) {
      WatchSourcesSortOption.seedersDesc => right.seeders.compareTo(
        left.seeders,
      ),
      WatchSourcesSortOption.publishedAtDesc => _descending(
        DateTime.tryParse(left.time),
        DateTime.tryParse(right.time),
      ),
      WatchSourcesSortOption.downloadsDesc => right.downloads.compareTo(
        left.downloads,
      ),
      WatchSourcesSortOption.sizeDesc => _descending<num>(
        sizes[left.size],
        sizes[right.size],
      ),
      WatchSourcesSortOption.titleAsc => 0,
    };
    return byOption == 0
        ? left.title.toLowerCase().compareTo(right.title.toLowerCase())
        : byOption;
  });

  return filtered;
}

int _descending<T extends Comparable<T>>(T? left, T? right) {
  if (right == null) return left == null ? 0 : -1;
  if (left == null) return 1;
  return right.compareTo(left);
}
