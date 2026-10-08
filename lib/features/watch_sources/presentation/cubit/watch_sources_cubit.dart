import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_repository.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_state.dart';
import 'package:iris/features/watch_sources/presentation/models/watch_sources_sort_option.dart';

class WatchSourcesCubit extends Cubit<WatchSourcesState> {
  WatchSourcesCubit({
    required this.animeId,
    required this.animeTitle,
    required this.searchTitles,
    required WatchSourcesRepository repository,
  }) : _repository = repository,
       super(const WatchSourcesInitial());

  final String animeId;

  /// How history names the anime of a release played from here.
  final String animeTitle;

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

  filtered.sort((left, right) {
    switch (sortOption) {
      case WatchSourcesSortOption.seedersDesc:
        final seedersResult = right.seeders.compareTo(left.seeders);
        if (seedersResult != 0) {
          return seedersResult;
        }
        return left.title.toLowerCase().compareTo(right.title.toLowerCase());
      case WatchSourcesSortOption.publishedAtDesc:
        final rightDate = DateTime.tryParse(right.time);
        final leftDate = DateTime.tryParse(left.time);

        if (leftDate == null && rightDate == null) {
          return left.title.toLowerCase().compareTo(right.title.toLowerCase());
        }
        if (leftDate == null) {
          return 1;
        }
        if (rightDate == null) {
          return -1;
        }

        final dateResult = rightDate.compareTo(leftDate);
        if (dateResult != 0) {
          return dateResult;
        }
        return left.title.toLowerCase().compareTo(right.title.toLowerCase());
      case WatchSourcesSortOption.downloadsDesc:
        final downloadsResult = right.downloads.compareTo(left.downloads);
        if (downloadsResult != 0) {
          return downloadsResult;
        }
        return left.title.toLowerCase().compareTo(right.title.toLowerCase());
      case WatchSourcesSortOption.titleAsc:
        return left.title.toLowerCase().compareTo(right.title.toLowerCase());
    }
  });

  return filtered;
}
