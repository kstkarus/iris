enum AnimeListSortOption { popularity, score, airedOn }

enum AnimeKindFilter { tv, movie, ova, ona }

enum AnimeStatusFilter { released, ongoing, announced }

class AnimeListFilters {
  const AnimeListFilters({this.kinds = const {}, this.statuses = const {}});

  final Set<AnimeKindFilter> kinds;
  final Set<AnimeStatusFilter> statuses;

  bool get hasAny => kinds.isNotEmpty || statuses.isNotEmpty;

  AnimeListFilters copyWith({
    Set<AnimeKindFilter>? kinds,
    Set<AnimeStatusFilter>? statuses,
  }) {
    return AnimeListFilters(
      kinds: kinds ?? this.kinds,
      statuses: statuses ?? this.statuses,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AnimeListFilters &&
        _sameSet(other.kinds, kinds) &&
        _sameSet(other.statuses, statuses);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(_orderedKinds(kinds)),
    Object.hashAll(_orderedStatuses(statuses)),
  );
}

class AnimeListQuery {
  const AnimeListQuery({
    required this.page,
    required this.limit,
    this.search = '',
    this.sort = AnimeListSortOption.popularity,
    this.filters = const AnimeListFilters(),
  });

  final int page;
  final int limit;
  final String search;
  final AnimeListSortOption sort;
  final AnimeListFilters filters;

  Map<String, dynamic> get variables {
    return {
      'page': page,
      'limit': limit,
      'search': search.isEmpty ? null : search,
      'order': sort.apiValue,
      'kind': _serializeKinds(filters.kinds),
      'status': _serializeStatuses(filters.statuses),
    };
  }

  AnimeListQuery copyWith({
    int? page,
    int? limit,
    String? search,
    AnimeListSortOption? sort,
    AnimeListFilters? filters,
  }) {
    return AnimeListQuery(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      search: search ?? this.search,
      sort: sort ?? this.sort,
      filters: filters ?? this.filters,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AnimeListQuery &&
        other.page == page &&
        other.limit == limit &&
        other.search == search &&
        other.sort == sort &&
        other.filters == filters;
  }

  @override
  int get hashCode => Object.hash(page, limit, search, sort, filters);
}

extension AnimeListSortOptionX on AnimeListSortOption {
  String get apiValue {
    switch (this) {
      case AnimeListSortOption.popularity:
        return 'popularity';
      case AnimeListSortOption.score:
        return 'ranked';
      case AnimeListSortOption.airedOn:
        return 'aired_on';
    }
  }
}

extension AnimeKindFilterX on AnimeKindFilter {
  String get apiValue {
    switch (this) {
      case AnimeKindFilter.tv:
        return 'tv';
      case AnimeKindFilter.movie:
        return 'movie';
      case AnimeKindFilter.ova:
        return 'ova';
      case AnimeKindFilter.ona:
        return 'ona';
    }
  }
}

extension AnimeStatusFilterX on AnimeStatusFilter {
  String get apiValue {
    switch (this) {
      case AnimeStatusFilter.released:
        return 'released';
      case AnimeStatusFilter.ongoing:
        return 'ongoing';
      case AnimeStatusFilter.announced:
        return 'anons';
    }
  }
}

String? _serializeKinds(Set<AnimeKindFilter> kinds) {
  if (kinds.isEmpty) {
    return null;
  }

  return _orderedKinds(kinds).map((kind) => kind.apiValue).join(',');
}

String? _serializeStatuses(Set<AnimeStatusFilter> statuses) {
  if (statuses.isEmpty) {
    return null;
  }

  return _orderedStatuses(statuses).map((status) => status.apiValue).join(',');
}

bool _sameSet<T>(Set<T> first, Set<T> second) {
  if (first.length != second.length) {
    return false;
  }

  for (final item in first) {
    if (!second.contains(item)) {
      return false;
    }
  }

  return true;
}

List<AnimeKindFilter> _orderedKinds(Set<AnimeKindFilter> kinds) {
  return AnimeKindFilter.values.where(kinds.contains).toList(growable: false);
}

List<AnimeStatusFilter> _orderedStatuses(Set<AnimeStatusFilter> statuses) {
  return AnimeStatusFilter.values
      .where(statuses.contains)
      .toList(growable: false);
}
