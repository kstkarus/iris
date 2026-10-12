import 'package:iris/features/characters/domain/entities/character_summary.dart';

/// How much of a story is about a character.
enum CharacterRole { main, supporting }

/// A character as one anime has it.
class AnimeCharacter {
  const AnimeCharacter({required this.character, required this.role});

  final CharacterSummary character;
  final CharacterRole role;

  @override
  bool operator ==(Object other) =>
      other is AnimeCharacter &&
      other.character == character &&
      other.role == role;

  @override
  int get hashCode => Object.hash(character, role);
}
