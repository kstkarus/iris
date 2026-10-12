import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/characters/domain/entities/anime_character.dart';
import 'package:iris/features/characters/domain/entities/character_details.dart';
import 'package:iris/features/characters/domain/entities/character_summary.dart';
import 'package:iris/features/characters/domain/repositories/characters_repository.dart';

/// The same few characters in every anime, for the mock build.
class MockCharactersRepository implements CharactersRepository {
  const MockCharactersRepository();

  static final _characters = [
    const AnimeCharacter(
      character: CharacterSummary(
        id: '1',
        name: 'Mock Hero',
        russian: 'Пробный герой',
        posterUrl: '',
      ),
      role: CharacterRole.main,
    ),
    const AnimeCharacter(
      character: CharacterSummary(
        id: '2',
        name: 'Mock Rival',
        russian: 'Пробный соперник',
        posterUrl: '',
      ),
      role: CharacterRole.main,
    ),
    for (var index = 3; index < 12; index++)
      AnimeCharacter(
        character: CharacterSummary(
          id: '$index',
          name: 'Mock Townsperson $index',
          russian: 'Пробный горожанин $index',
          posterUrl: '',
        ),
        role: CharacterRole.supporting,
      ),
  ];

  @override
  Future<List<AnimeCharacter>> animeCharacters(String animeId) async =>
      _characters;

  @override
  Future<CharacterDetails> character(String characterId) async {
    final found = _characters.firstWhere(
      (item) => item.character.id == characterId,
      orElse: () => _characters.first,
    );
    return CharacterDetails(
      character: found.character,
      japanese: '',
      altName: '',
      description: 'A character of the mock catalog.',
      appearances: [
        CharacterAppearance(
          anime: const AnimeSummary(
            id: '1',
            name: 'Mock Anime',
            russian: 'Пробное аниме',
            kind: 'tv',
            score: 8,
            status: 'released',
            episodes: 12,
            episodesAired: 12,
            airedOn: '2024-01-01',
            posterUrl: '',
          ),
          role: found.role,
        ),
      ],
    );
  }
}
