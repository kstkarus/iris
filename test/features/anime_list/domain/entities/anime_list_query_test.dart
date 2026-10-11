import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';

void main() {
  test('signing out leaves the other filters as they are', () {
    const filters = AnimeListFilters(
      kinds: {AnimeKindFilter.tv},
      myList: {UserRateStatus.watching},
      hideCompleted: true,
    );

    expect(filters.usesMyList, isTrue);
    expect(
      filters.withoutMyList(),
      const AnimeListFilters(kinds: {AnimeKindFilter.tv}),
    );
  });
}
