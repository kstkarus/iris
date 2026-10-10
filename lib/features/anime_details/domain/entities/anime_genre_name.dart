/// A genre or audience of a title, by its names.
class AnimeGenreName {
  const AnimeGenreName({required this.name, required this.russian});

  final String name;

  /// Empty when Shikimori has none.
  final String russian;

  @override
  bool operator ==(Object other) =>
      other is AnimeGenreName && other.name == name && other.russian == russian;

  @override
  int get hashCode => Object.hash(name, russian);
}
