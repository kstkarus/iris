import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/anime_list/data/mappers/shikimori_anime_mapper.dart';
import 'package:iris/features/anime_list/data/models/shikimori_anime_dto.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';

void main() {
  test('Shikimori anime dto maps to a domain item', () {
    const dto = ShikimoriAnimeDto(
      id: '5114',
      malId: '5114',
      name: 'Fullmetal Alchemist: Brotherhood',
      russian: 'Стальной алхимик: Братство',
      kind: 'tv',
      score: 9.12,
      status: 'released',
      episodes: 64,
      episodesAired: 64,
      airedOn: ShikimoriAiredOnDto(
        year: 2009,
        month: 4,
        day: 5,
        date: '2009-04-05',
      ),
      poster: ShikimoriPosterDto(
        id: '100001',
        originalUrl: 'https://shikimori.one/posters/5114/original.jpg',
        mainUrl: 'https://shikimori.one/posters/5114/main.jpg',
      ),
    );

    final item = mapShikimoriAnimeToDomain(dto);

    expect(
      item,
      const AnimeListItem(
        id: '5114',
        name: 'Fullmetal Alchemist: Brotherhood',
        russian: 'Стальной алхимик: Братство',
        kind: 'tv',
        score: 9.12,
        status: 'released',
        episodes: 64,
        episodesAired: 64,
        airedOn: '2009-04-05',
        posterMainUrl: 'https://shikimori.one/posters/5114/main.jpg',
      ),
    );
  });

  test('the user entry comes along when the page was signed in', () {
    final dto = ShikimoriAnimeDto.fromJson(const {
      'id': '1',
      'name': 'Frieren',
      'userRate': {'id': '7', 'status': 'watching', 'episodes': 5, 'score': 9},
    });

    expect(
      mapShikimoriAnimeToDomain(dto).userRate,
      const UserRate(
        id: '7',
        status: UserRateStatus.watching,
        episodes: 5,
        score: 9,
      ),
    );
    expect(
      mapShikimoriAnimeToDomain(
        ShikimoriAnimeDto.fromJson(const {'id': '1', 'userRate': null}),
      ).userRate,
      isNull,
    );
  });
}
