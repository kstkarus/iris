import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/characters/domain/entities/anime_character.dart';
import 'package:iris/features/characters/domain/entities/character_summary.dart';
import 'package:iris/shared/utils/equality.dart';

/// A character's page: who they are and where they appear.
class CharacterDetails {
  const CharacterDetails({
    required this.character,
    required this.japanese,
    required this.altName,
    required this.description,
    required this.appearances,
  });

  final CharacterSummary character;

  /// The name in Japanese; empty when unknown.
  final String japanese;

  /// Other names and titles the character goes by; empty when none.
  final String altName;

  /// Plain text, paragraphs apart by blank lines; empty when none.
  final String description;

  /// Every anime the character is in, as Shikimori lists them.
  final List<CharacterAppearance> appearances;

  @override
  bool operator ==(Object other) =>
      other is CharacterDetails &&
      other.character == character &&
      other.japanese == japanese &&
      other.altName == altName &&
      other.description == description &&
      sameList(other.appearances, appearances);

  @override
  int get hashCode => Object.hash(
    character,
    japanese,
    altName,
    description,
    Object.hashAll(appearances),
  );
}

/// An anime the character is in, and how much it is about them.
class CharacterAppearance {
  const CharacterAppearance({required this.anime, required this.role});

  final AnimeSummary anime;
  final CharacterRole role;

  @override
  bool operator ==(Object other) =>
      other is CharacterAppearance &&
      other.anime == anime &&
      other.role == role;

  @override
  int get hashCode => Object.hash(anime, role);
}
