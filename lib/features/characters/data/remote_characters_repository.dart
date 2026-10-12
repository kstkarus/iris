import 'package:iris/features/characters/data/shikimori_character_parser.dart';
import 'package:iris/features/characters/domain/entities/anime_character.dart';
import 'package:iris/features/characters/domain/entities/character_details.dart';
import 'package:iris/features/characters/domain/repositories/characters_repository.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';
import 'package:iris/shared/network/shikimori_rest_client.dart';

/// An anime's characters through GraphQL; a character's page through
/// REST, the only one that lists the anime they are in.
///
/// An anime's list is kept for the session: its page and the page of all
/// its characters both ask, and a long series' list is large. A failed
/// request is asked again next time.
class RemoteCharactersRepository implements CharactersRepository {
  RemoteCharactersRepository({
    required ShikimoriGraphQlClient graphQl,
    required ShikimoriRestClient rest,
  }) : _graphQl = graphQl,
       _rest = rest;

  final ShikimoriGraphQlClient _graphQl;
  final ShikimoriRestClient _rest;
  final _animeCharacters = <String, Future<List<AnimeCharacter>>>{};

  @override
  Future<List<AnimeCharacter>> animeCharacters(String animeId) {
    final kept = _animeCharacters[animeId];
    if (kept != null) return kept;
    final future = _fetchAnimeCharacters(animeId);
    _animeCharacters[animeId] = future;
    future.then<void>(
      (_) {},
      onError: (Object _) {
        _animeCharacters.remove(animeId);
      },
    );
    return future;
  }

  Future<List<AnimeCharacter>> _fetchAnimeCharacters(String animeId) async {
    final items = await _graphQl.queryList(
      'animes',
      document: _animeCharactersQuery,
      variables: {'id': animeId},
    );
    if (items.isEmpty) {
      throw ResourceNotFoundException('Anime not found for id: $animeId');
    }
    final first = items.first;
    final roles = first is Map ? first['characterRoles'] : null;
    if (roles is! List) {
      throw const RemoteResponseException('`characterRoles` is not a list.');
    }
    return [for (final role in roles) ?parseShikimoriCharacterRole(role)];
  }

  @override
  Future<CharacterDetails> character(String characterId) async {
    final data = await _rest.get('/api/characters/$characterId');
    final details = parseShikimoriCharacter(data);
    if (details == null) {
      throw const RemoteResponseException('Character response has no id.');
    }
    return details;
  }
}

const _animeCharactersQuery = r'''
query AnimeCharacters($id: String!) {
  animes(ids: $id, limit: 1, censored: true) {
    characterRoles {
      rolesEn
      character {
        id
        name
        russian
        poster {
          mainUrl
        }
      }
    }
  }
}
''';
