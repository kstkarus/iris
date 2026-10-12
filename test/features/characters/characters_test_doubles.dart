import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/characters/domain/entities/anime_character.dart';
import 'package:iris/features/characters/domain/entities/character_details.dart';
import 'package:iris/features/characters/domain/entities/character_summary.dart';
import 'package:iris/features/characters/domain/repositories/characters_repository.dart';

/// Answers with [characters] and [details], or fails while [failing].
class FakeCharactersRepository implements CharactersRepository {
  FakeCharactersRepository({this.characters = const [], this.details});

  List<AnimeCharacter> characters;
  CharacterDetails? details;
  bool failing = false;
  int reads = 0;

  @override
  Future<List<AnimeCharacter>> animeCharacters(String animeId) async {
    reads++;
    if (failing) throw Exception('offline');
    return characters;
  }

  @override
  Future<CharacterDetails> character(String characterId) async {
    reads++;
    final details = this.details;
    if (failing || details == null) throw Exception('offline');
    return details;
  }
}

AnimeCharacter testCharacter(
  String id, {
  CharacterRole role = CharacterRole.supporting,
  String? name,
  String russian = '',
}) => AnimeCharacter(
  character: CharacterSummary(
    id: id,
    name: name ?? 'Character $id',
    russian: russian,
    posterUrl: '',
  ),
  role: role,
);

CharacterAppearance testAppearance(
  String id, {
  String kind = 'tv',
  String airedOn = '2020-01-01',
  CharacterRole role = CharacterRole.main,
  String russian = '',
}) => CharacterAppearance(
  anime: AnimeSummary(
    id: id,
    name: 'Anime $id',
    russian: russian,
    kind: kind,
    score: 8,
    status: 'released',
    episodes: 12,
    episodesAired: 12,
    airedOn: airedOn,
    posterUrl: 'poster-$id',
  ),
  role: role,
);
