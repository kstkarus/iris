/// What every list of anime knows of a title, and what its title page can
/// show before the details load.
class AnimeSummary {
  const AnimeSummary({
    required this.id,
    required this.name,
    required this.russian,
    this.english = '',
    required this.kind,
    required this.score,
    required this.status,
    required this.episodes,
    required this.episodesAired,
    required this.airedOn,
    required this.posterUrl,
    this.nextEpisodeAt,
  });

  final String id;
  final String name;
  final String russian;

  /// The licensed English title; empty when there is none.
  final String english;
  final String kind;
  final double score;
  final String status;
  final int episodes;
  final int episodesAired;

  /// As much of the date as is known: `2028`, `2028-03` or `2028-03-15`.
  final String airedOn;
  final String posterUrl;

  /// When the next episode airs, while the anime is airing; lists that do
  /// not ask for it leave it null.
  final DateTime? nextEpisodeAt;

  AnimeSummary copyWith({int? episodesAired}) => AnimeSummary(
    id: id,
    name: name,
    russian: russian,
    english: english,
    kind: kind,
    score: score,
    status: status,
    episodes: episodes,
    episodesAired: episodesAired ?? this.episodesAired,
    airedOn: airedOn,
    posterUrl: posterUrl,
    nextEpisodeAt: nextEpisodeAt,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnimeSummary &&
        other.id == id &&
        other.name == name &&
        other.russian == russian &&
        other.english == english &&
        other.kind == kind &&
        other.score == score &&
        other.status == status &&
        other.episodes == episodes &&
        other.episodesAired == episodesAired &&
        other.airedOn == airedOn &&
        other.posterUrl == posterUrl &&
        other.nextEpisodeAt == nextEpisodeAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    russian,
    english,
    kind,
    score,
    status,
    episodes,
    episodesAired,
    airedOn,
    posterUrl,
    nextEpisodeAt,
  );
}
