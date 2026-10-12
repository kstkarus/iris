import 'package:iris/features/characters/domain/entities/anime_character.dart';
import 'package:iris/features/characters/domain/entities/character_details.dart';

abstract interface class CharactersRepository {
  /// Everyone in the anime, as Shikimori lists them: a long-running
  /// series has well over a thousand.
  Future<List<AnimeCharacter>> animeCharacters(String animeId);

  Future<CharacterDetails> character(String characterId);
}
