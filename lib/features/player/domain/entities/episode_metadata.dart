/// Metadata for one episode of an anime (from Tenrai / MyAnimeList).
class EpisodeMetadata {
  const EpisodeMetadata({
    required this.number,
    this.title,
    this.filler = false,
    this.recap = false,
  });

  final int number;
  final String? title;
  final bool filler;
  final bool recap;

  bool get hasTitle => title != null && title!.trim().isNotEmpty;

  bool get hasTag => filler || recap;

  bool get isEmpty => !hasTitle && !hasTag;

  @override
  bool operator ==(Object other) =>
      other is EpisodeMetadata &&
      other.number == number &&
      other.title == title &&
      other.filler == filler &&
      other.recap == recap;

  @override
  int get hashCode => Object.hash(number, title, filler, recap);
}
