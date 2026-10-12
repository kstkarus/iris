import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/characters/domain/entities/anime_character.dart';
import 'package:iris/features/characters/domain/entities/character_details.dart';
import 'package:iris/features/characters/domain/entities/character_summary.dart';
import 'package:iris/shared/network/shikimori_api.dart';
import 'package:iris/shared/utils/json_read.dart';
import 'package:iris/shared/utils/shikimori_markup.dart';

/// A `CharacterRole` of the GraphQL API; null without a character.
AnimeCharacter? parseShikimoriCharacterRole(Object? json) {
  final role = jsonMap(json);
  final character = jsonMap(role['character']);
  final id = character['id'];
  if (id == null) return null;
  return AnimeCharacter(
    character: CharacterSummary(
      id: '$id',
      name: jsonString(character['name']),
      russian: jsonString(character['russian']),
      posterUrl: jsonString(jsonMap(character['poster'])['mainUrl']),
    ),
    role: _role(role['rolesEn']),
  );
}

/// A character of the REST API, with the anime they are in; null without
/// an id.
CharacterDetails? parseShikimoriCharacter(Object? json) {
  final character = jsonMap(json);
  final id = character['id'];
  if (id == null) return null;
  final animes = character['animes'];
  return CharacterDetails(
    character: CharacterSummary(
      id: '$id',
      name: jsonString(character['name']),
      russian: jsonString(character['russian']),
      posterUrl: _imageUrl(character['image']),
    ),
    japanese: jsonString(character['japanese']),
    altName: jsonString(character['altname']),
    description: sanitizeShikimoriDescription(
      jsonString(character['description']),
    ),
    appearances: [
      if (animes is List)
        for (final anime in animes) ?_appearance(anime),
    ],
  );
}

CharacterAppearance? _appearance(Object? json) {
  final anime = jsonMap(json);
  final id = anime['id'];
  if (id == null) return null;
  final status = jsonString(anime['status']);
  final episodes = jsonInt(anime['episodes']);
  final aired = jsonInt(anime['episodes_aired']);
  return CharacterAppearance(
    anime: AnimeSummary(
      id: '$id',
      name: jsonString(anime['name']),
      russian: jsonString(anime['russian']),
      kind: jsonString(anime['kind']),
      score: double.tryParse('${anime['score']}') ?? 0,
      status: status,
      episodes: episodes,
      // REST leaves it 0 once a title is out.
      episodesAired: status == 'released' && aired == 0 ? episodes : aired,
      airedOn: jsonString(anime['aired_on']),
      posterUrl: _imageUrl(anime['image']),
    ),
    role: _role(anime['roles']),
  );
}

/// Main when any of [roles] is; a character listed with none is minor.
CharacterRole _role(Object? roles) => roles is List && roles.contains('Main')
    ? CharacterRole.main
    : CharacterRole.supporting;

/// The original of a REST `image`, whose paths are the site's own; empty
/// for Shikimori's stand-in for a missing picture.
String _imageUrl(Object? image) {
  final path = jsonString(jsonMap(image)['original']);
  if (path.isEmpty || path.contains('/missing_')) return '';
  return path.startsWith('/') ? '${ShikimoriApi.baseUrl}$path' : path;
}
