import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/anime_details/data/mappers/shikimori_anime_details_mapper.dart';
import 'package:iris/features/anime_details/data/models/shikimori_anime_details_dto.dart';
import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/features/anime_details/domain/entities/related_anime.dart';

void main() {
  test('Shikimori anime details dto maps to a domain entity', () {
    const dto = ShikimoriAnimeDetailsDto(
      id: '5114',
      malId: '5114',
      name: 'Fullmetal Alchemist: Brotherhood',
      russian: 'Fullmetal Alchemist: Brotherhood RU',
      description:
          'Two brothers search for a Philosopher\'s Stone after a failed ritual.',
      kind: 'tv',
      score: 9.12,
      status: 'released',
      episodes: 64,
      episodesAired: 64,
      airedOn: ShikimoriDetailsAiredOnDto(
        year: 2009,
        month: 4,
        day: 5,
        date: '2009-04-05',
      ),
      poster: ShikimoriDetailsPosterDto(
        id: 'poster-5114',
        originalUrl: 'https://shikimori.one/posters/5114/original.jpg',
      ),
    );

    final details = mapShikimoriAnimeDetailsToDomain(dto);

    expect(
      details,
      const AnimeDetails(
        id: '5114',
        name: 'Fullmetal Alchemist: Brotherhood',
        russian: 'Fullmetal Alchemist: Brotherhood RU',
        description:
            'Two brothers search for a Philosopher\'s Stone after a failed ritual.',
        kind: 'tv',
        score: 9.12,
        status: 'released',
        episodes: 64,
        episodesAired: 64,
        airedOn: '2009-04-05',
        posterOriginalUrl: 'https://shikimori.one/posters/5114/original.jpg',
      ),
    );
  });

  test('description keeps the text of wiki links and BBCode tags', () {
    expect(
      sanitizeShikimoriDescription(
        'Изнывающий от скуки [[Бог смерти|бог смерти]] '
        '[character=71]Рюк[/character]  бросает тетрадь. '
        'Убийцу окрещают [[Кира]].',
      ),
      'Изнывающий от скуки бог смерти Рюк бросает тетрадь. '
      'Убийцу окрещают Кира.',
    );
  });

  test('related anime map with their relation; manga is left out', () {
    final dto = ShikimoriAnimeDetailsDto.fromJson({
      'id': '52991',
      'name': 'Sousou no Frieren',
      'related': [
        {
          'relationKind': 'sequel',
          'anime': {
            'id': '59978',
            'name': 'Sousou no Frieren 2nd Season',
            'russian': 'Провожающая в последний путь Фрирен 2',
            'english': "Frieren: Beyond Journey's End Season 2",
            'kind': 'tv',
            'score': 9.1,
            'status': 'released',
            'episodes': 10,
            'episodesAired': 10,
            'airedOn': {'date': '2026-01-16'},
            'poster': {'mainUrl': 'https://shikimori.io/poster/59978.jpg'},
          },
          'manga': null,
        },
        {
          'relationKind': 'adaptation',
          'anime': null,
          'manga': {'id': '126287'},
        },
        {
          'relationKind': 'something_new',
          'anime': {'id': '1', 'name': 'Unknown kin'},
        },
      ],
    });

    final related = mapShikimoriAnimeDetailsToDomain(dto).related;

    expect(related, const [
      RelatedAnime(
        relation: AnimeRelation.sequel,
        id: '59978',
        name: 'Sousou no Frieren 2nd Season',
        russian: 'Провожающая в последний путь Фрирен 2',
        english: "Frieren: Beyond Journey's End Season 2",
        kind: 'tv',
        score: 9.1,
        status: 'released',
        episodes: 10,
        episodesAired: 10,
        airedOn: '2026-01-16',
        posterUrl: 'https://shikimori.io/poster/59978.jpg',
      ),
      RelatedAnime(
        relation: AnimeRelation.other,
        id: '1',
        name: 'Unknown kin',
        russian: '',
        kind: '',
        score: 0,
        status: '',
        episodes: 0,
        episodesAired: 0,
        airedOn: '',
        posterUrl: '',
      ),
    ]);
  });

  test('a date known only by its year stays a year', () {
    // Shikimori fills `date` with the first of January in that case.
    final dto = ShikimoriAnimeDetailsDto.fromJson({
      'id': '53529',
      'name': 'Upcoming',
      'airedOn': {
        'year': 2028,
        'month': null,
        'day': null,
        'date': '2028-01-01',
      },
      'related': [
        {
          'relationKind': 'sequel',
          'anime': {
            'id': '2',
            'name': 'Next',
            'airedOn': {
              'year': 2029,
              'month': 4,
              'day': null,
              'date': '2029-04-01',
            },
          },
        },
      ],
    });

    final details = mapShikimoriAnimeDetailsToDomain(dto);

    expect(details.airedOn, '2028');
    expect(details.related.single.airedOn, '2029-04');
  });
}
