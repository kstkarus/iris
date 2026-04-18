import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';

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

  AnimeListPageResult copyWith({
    List<AnimeListItem>? items,
    int? page,
    bool? hasMore,
    String? query,
  }) {
    return AnimeListPageResult(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      query: query ?? this.query,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AnimeListPageResult &&
        _sameItems(other.items, items) &&
        other.page == page &&
        other.hasMore == hasMore &&
        other.query == query;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(items), page, hasMore, query);
}

bool _sameItems(List<AnimeListItem> first, List<AnimeListItem> second) {
  if (first.length != second.length) {
    return false;
  }

  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }

  return true;
}
