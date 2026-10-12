import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/characters/data/remote_characters_repository.dart';
import 'package:iris/features/characters/domain/entities/anime_character.dart';
import 'package:iris/features/characters/domain/entities/character_details.dart';
import 'package:iris/features/characters/domain/entities/character_summary.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';
import 'package:iris/shared/network/shikimori_rest_client.dart';

import '../../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;
  late FakeReply Function(RequestOptions) server;

  RemoteCharactersRepository repository() {
    adapter = FakeHttpAdapter((options) => server(options));
    final dio = Dio(BaseOptions(baseUrl: 'https://shikimori.io'))
      ..httpClientAdapter = adapter;
    return RemoteCharactersRepository(
      graphQl: ShikimoriGraphQlClient(dio: dio),
      rest: ShikimoriRestClient(dio: dio),
    );
  }

  test(
    'reads an anime\'s characters with their roles, once a session',
    () async {
      server = (_) => const FakeReply(200, {
        'data': {
          'animes': [
            {
              'characterRoles': [
                {
                  'rolesEn': ['Main'],
                  'character': {
                    'id': '184947',
                    'name': 'Frieren',
                    'russian': 'Фрирен',
                    'poster': {'mainUrl': 'https://shikimori.io/frieren.webp'},
                  },
                },
                {
                  'rolesEn': ['Supporting'],
                  'character': {
                    'id': '206722',
                    'name': 'Aura',
                    'russian': null,
                    'poster': null,
                  },
                },
                {
                  'rolesEn': ['Main'],
                  'character': null,
                },
              ],
            },
          ],
        },
      });
      final characters = repository();

      final list = await characters.animeCharacters('52991');
      await characters.animeCharacters('52991');

      expect(list, const [
        AnimeCharacter(
          character: CharacterSummary(
            id: '184947',
            name: 'Frieren',
            russian: 'Фрирен',
            posterUrl: 'https://shikimori.io/frieren.webp',
          ),
          role: CharacterRole.main,
        ),
        AnimeCharacter(
          character: CharacterSummary(
            id: '206722',
            name: 'Aura',
            russian: '',
            posterUrl: '',
          ),
          role: CharacterRole.supporting,
        ),
      ]);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.data, isA<Map<String, dynamic>>());
      expect((adapter.requests.single.data as Map)['variables'], {
        'id': '52991',
      });
    },
  );

  test('a failed read is asked again next time', () async {
    var replies = 0;
    server = (_) => replies++ == 0
        ? const FakeReply(500)
        : const FakeReply(200, {
            'data': {
              'animes': [
                {'characterRoles': []},
              ],
            },
          });
    final characters = repository();

    await expectLater(characters.animeCharacters('1'), throwsA(anything));
    expect(await characters.animeCharacters('1'), isEmpty);
    expect(adapter.requests, hasLength(2));
  });

  test('reads a character with the anime they are in', () async {
    server = (_) => const FakeReply(200, {
      'id': 11,
      'name': 'Edward Elric',
      'russian': 'Эдвард Элрик',
      'japanese': 'エドワード・エルリック',
      'altname': 'Fullmetal Alchemist',
      'image': {'original': '/system/characters/original/11.jpg?1'},
      'description':
          'Младший брат — [character=12]Альфонс[/character].\r\n'
          '[h3]Внешность[/h3]Невысокий.',
      'animes': [
        {
          'id': 5114,
          'name': 'Fullmetal Alchemist: Brotherhood',
          'russian': 'Стальной алхимик: Братство',
          'image': {'original': '/assets/globals/missing_original.jpg'},
          'kind': 'tv',
          'score': '9.1',
          'status': 'released',
          'episodes': 64,
          'episodes_aired': 0,
          'aired_on': '2009-04-05',
          'roles': ['Main'],
        },
        {
          'id': 430,
          'name': 'Fullmetal Alchemist: The Conqueror of Shamballa',
          'russian': null,
          'kind': 'movie',
          'score': null,
          'status': 'released',
          'episodes': 1,
          'episodes_aired': 1,
          'aired_on': null,
          'roles': ['Supporting'],
        },
      ],
    });

    final details = await repository().character('11');

    expect(adapter.requests.single.path, '/api/characters/11');
    expect(
      details,
      const CharacterDetails(
        character: CharacterSummary(
          id: '11',
          name: 'Edward Elric',
          russian: 'Эдвард Элрик',
          posterUrl: 'https://shikimori.io/system/characters/original/11.jpg?1',
        ),
        japanese: 'エドワード・エルリック',
        altName: 'Fullmetal Alchemist',
        description: 'Младший брат — Альфонс.\n\nВнешность\nНевысокий.',
        appearances: [
          CharacterAppearance(
            anime: AnimeSummary(
              id: '5114',
              name: 'Fullmetal Alchemist: Brotherhood',
              russian: 'Стальной алхимик: Братство',
              kind: 'tv',
              score: 9.1,
              status: 'released',
              episodes: 64,
              episodesAired: 64,
              airedOn: '2009-04-05',
              posterUrl: '',
            ),
            role: CharacterRole.main,
          ),
          CharacterAppearance(
            anime: AnimeSummary(
              id: '430',
              name: 'Fullmetal Alchemist: The Conqueror of Shamballa',
              russian: '',
              kind: 'movie',
              score: 0,
              status: 'released',
              episodes: 1,
              episodesAired: 1,
              airedOn: '',
              posterUrl: '',
            ),
            role: CharacterRole.supporting,
          ),
        ],
      ),
    );
  });
}
