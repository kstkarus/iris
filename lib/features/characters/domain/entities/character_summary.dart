/// What a list of characters knows of one, and what the character's page
/// can show before the rest loads.
class CharacterSummary {
  const CharacterSummary({
    required this.id,
    required this.name,
    required this.russian,
    required this.posterUrl,
  });

  final String id;

  /// The romanised name.
  final String name;

  /// The name in Russian; empty when there is none.
  final String russian;

  /// The portrait, 2:3; empty when there is none.
  final String posterUrl;

  @override
  bool operator ==(Object other) =>
      other is CharacterSummary &&
      other.id == id &&
      other.name == name &&
      other.russian == russian &&
      other.posterUrl == posterUrl;

  @override
  int get hashCode => Object.hash(id, name, russian, posterUrl);
}
