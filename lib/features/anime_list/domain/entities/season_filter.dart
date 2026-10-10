enum AnimeSeason { winter, spring, summer, fall }

enum SeasonFilterKind { season, year, decade, before2000 }

/// A stretch of air dates to filter by, fixed when it is offered: "this
/// season" chosen in October stays fall even past New Year.
class SeasonFilter {
  const SeasonFilter.season(AnimeSeason this.season, this.year)
    : kind = SeasonFilterKind.season;

  const SeasonFilter.year(this.year)
    : kind = SeasonFilterKind.year,
      season = null;

  /// [year] is the decade's first year, e.g. 2010.
  const SeasonFilter.decade(this.year)
    : kind = SeasonFilterKind.decade,
      season = null;

  const SeasonFilter.before2000()
    : kind = SeasonFilterKind.before2000,
      year = 0,
      season = null;

  final SeasonFilterKind kind;
  final int year;
  final AnimeSeason? season;

  /// Shikimori's `season` value: `fall_2026`, `2025`, `2010_2019`,
  /// `1900_1999`.
  String get apiValue => switch (kind) {
    SeasonFilterKind.season => '${season!.name}_$year',
    SeasonFilterKind.year => '$year',
    SeasonFilterKind.decade => '${year}_${year + 9}',
    SeasonFilterKind.before2000 => '1900_1999',
  };

  @override
  bool operator ==(Object other) =>
      other is SeasonFilter && other.apiValue == apiValue;

  @override
  int get hashCode => apiValue.hashCode;
}

/// Shikimori's seasons follow the Japanese broadcast quarters: winter is
/// January to March, fall October to December.
AnimeSeason seasonOfMonth(int month) =>
    AnimeSeason.values[((month - 1) ~/ 3).clamp(0, 3)];

/// The stretches offered on [now]: this and the last season, this and the
/// last year, the decades since 2000, and everything older.
List<SeasonFilter> seasonFilterPresets(DateTime now) {
  final season = seasonOfMonth(now.month);
  final previous = season == AnimeSeason.winter
      ? SeasonFilter.season(AnimeSeason.fall, now.year - 1)
      : SeasonFilter.season(AnimeSeason.values[season.index - 1], now.year);
  final decade = now.year - now.year % 10;
  return [
    SeasonFilter.season(season, now.year),
    previous,
    SeasonFilter.year(now.year),
    SeasonFilter.year(now.year - 1),
    for (var start = decade; start >= 2000; start -= 10)
      SeasonFilter.decade(start),
    const SeasonFilter.before2000(),
  ];
}
