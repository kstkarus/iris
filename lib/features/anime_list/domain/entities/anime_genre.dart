enum AnimeGenreKind { genre, demographic, theme }

/// A Shikimori genre, theme or audience, as the catalog filters by it.
class AnimeGenre {
  const AnimeGenre({
    required this.id,
    required this.name,
    required this.russian,
    required this.kind,
  });

  final String id;
  final String name;

  /// Empty when Shikimori has no Russian name.
  final String russian;
  final AnimeGenreKind kind;

  @override
  bool operator ==(Object other) => other is AnimeGenre && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
