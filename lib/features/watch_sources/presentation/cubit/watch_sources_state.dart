import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/presentation/models/watch_sources_sort_option.dart';
import 'package:iris/shared/utils/equality.dart';

sealed class WatchSourcesState {
  const WatchSourcesState();
}

final class WatchSourcesInitial extends WatchSourcesState {
  const WatchSourcesInitial();

  @override
  bool operator ==(Object other) => other is WatchSourcesInitial;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class WatchSourcesLoading extends WatchSourcesState {
  const WatchSourcesLoading();

  @override
  bool operator ==(Object other) => other is WatchSourcesLoading;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class WatchSourcesLoaded extends WatchSourcesState {
  const WatchSourcesLoaded({
    required this.allItems,
    required this.visibleItems,
    required this.searchQuery,
    required this.sortOption,
  });

  final List<WatchSourceItem> allItems;
  final List<WatchSourceItem> visibleItems;
  final String searchQuery;
  final WatchSourcesSortOption sortOption;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is WatchSourcesLoaded &&
        sameList(other.allItems, allItems) &&
        sameList(other.visibleItems, visibleItems) &&
        other.searchQuery == searchQuery &&
        other.sortOption == sortOption;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(allItems),
    Object.hashAll(visibleItems),
    searchQuery,
    sortOption,
  );
}

final class WatchSourcesEmpty extends WatchSourcesState {
  const WatchSourcesEmpty();

  @override
  bool operator ==(Object other) => other is WatchSourcesEmpty;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class WatchSourcesFailure extends WatchSourcesState {
  const WatchSourcesFailure();

  @override
  bool operator ==(Object other) => other is WatchSourcesFailure;

  @override
  int get hashCode => runtimeType.hashCode;
}
