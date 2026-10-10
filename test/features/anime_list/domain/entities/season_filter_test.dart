import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/anime_list/domain/entities/season_filter.dart';

void main() {
  List<String> presets(DateTime now) => [
    for (final season in seasonFilterPresets(now)) season.apiValue,
  ];

  test('seasons follow the broadcast quarters', () {
    expect(seasonOfMonth(1), AnimeSeason.winter);
    expect(seasonOfMonth(3), AnimeSeason.winter);
    expect(seasonOfMonth(4), AnimeSeason.spring);
    expect(seasonOfMonth(9), AnimeSeason.summer);
    expect(seasonOfMonth(10), AnimeSeason.fall);
    expect(seasonOfMonth(12), AnimeSeason.fall);
  });

  test('offers this and the last season, years and decades', () {
    expect(presets(DateTime(2026, 10, 10)), [
      'fall_2026',
      'summer_2026',
      '2026',
      '2025',
      '2020_2029',
      '2010_2019',
      '2000_2009',
      '1900_1999',
    ]);
  });

  test('in winter the last season is the fall before', () {
    expect(presets(DateTime(2027, 2, 1)).take(2), ['winter_2027', 'fall_2026']);
  });

  test('stretches are equal by what Shikimori is asked', () {
    expect(
      const SeasonFilter.season(AnimeSeason.fall, 2026),
      const SeasonFilter.season(AnimeSeason.fall, 2026),
    );
    expect(const SeasonFilter.decade(2010).apiValue, '2010_2019');
  });
}
