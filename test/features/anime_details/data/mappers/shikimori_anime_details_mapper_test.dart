import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/anime_details/data/mappers/shikimori_anime_details_mapper.dart';
import 'package:iris/features/anime_details/data/models/shikimori_anime_details_dto.dart';
import 'package:iris/features/anime_details/domain/entities/anime_details.dart';

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
}
