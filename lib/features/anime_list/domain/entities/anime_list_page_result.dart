import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/shared/utils/equality.dart';

class AnimeListPageResult {
  const AnimeListPageResult({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.query,
  });

  final List<AnimeListItem> items;
  final int page;
  final bool hasMore;
  final String query;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AnimeListPageResult &&
        sameList(other.items, items) &&
        other.page == page &&
        other.hasMore == hasMore &&
        other.query == query;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(items), page, hasMore, query);
}
