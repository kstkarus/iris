import 'package:iris/features/anime_list/data/models/shikimori_anime_dto.dart';

class MockAnimeListDataSource {
  Future<List<ShikimoriAnimeDto>> fetchPopularAnime() async {
    return _anime;
  }
}

const _anime = [
  ShikimoriAnimeDto(
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
  ),
  ShikimoriAnimeDto(
    id: '52991',
    malId: '52991',
    name: 'Frieren: Beyond Journey\'s End',
    russian: 'Провожающая в последний путь Фрирен',
    kind: 'tv',
    score: 9.27,
    status: 'released',
    episodes: 28,
    episodesAired: 28,
    airedOn: ShikimoriAiredOnDto(
      year: 2023,
      month: 9,
      day: 29,
      date: '2023-09-29',
    ),
    poster: ShikimoriPosterDto(
      id: '712058',
      originalUrl: 'https://shikimori.one/posters/52991/original.jpg',
      mainUrl: 'https://shikimori.one/posters/52991/main.webp',
    ),
  ),
  ShikimoriAnimeDto(
    id: '9253',
    malId: '9253',
    name: 'Steins;Gate',
    russian: 'Врата Штейна',
    kind: 'tv',
    score: 9.07,
    status: 'released',
    episodes: 24,
    episodesAired: 24,
    airedOn: ShikimoriAiredOnDto(
      year: 2011,
      month: 4,
      day: 6,
      date: '2011-04-06',
    ),
    poster: ShikimoriPosterDto(
      id: '100002',
      originalUrl: 'https://shikimori.one/posters/9253/original.jpg',
      mainUrl: 'https://shikimori.one/posters/9253/main.jpg',
    ),
  ),
  ShikimoriAnimeDto(
    id: '11061',
    malId: '11061',
    name: 'Hunter x Hunter (2011)',
    russian: 'Охотник х Охотник',
    kind: 'tv',
    score: 9.04,
    status: 'released',
    episodes: 148,
    episodesAired: 148,
    airedOn: ShikimoriAiredOnDto(
      year: 2011,
      month: 10,
      day: 2,
      date: '2011-10-02',
    ),
    poster: ShikimoriPosterDto(
      id: '100003',
      originalUrl: 'https://shikimori.one/posters/11061/original.jpg',
      mainUrl: 'https://shikimori.one/posters/11061/main.jpg',
    ),
  ),
  ShikimoriAnimeDto(
    id: '52299',
    malId: '52299',
    name: 'Solo Leveling',
    russian: 'Поднятие уровня в одиночку',
    kind: 'tv',
    score: 8.34,
    status: 'released',
    episodes: 12,
    episodesAired: 12,
    airedOn: ShikimoriAiredOnDto(
      year: 2024,
      month: 1,
      day: 7,
      date: '2024-01-07',
    ),
    poster: ShikimoriPosterDto(
      id: '100004',
      originalUrl: 'https://shikimori.one/posters/52299/original.jpg',
      mainUrl: 'https://shikimori.one/posters/52299/main.webp',
    ),
  ),
  ShikimoriAnimeDto(
    id: '1535',
    malId: '1535',
    name: 'Death Note',
    russian: 'Тетрадь смерти',
    kind: 'tv',
    score: 8.61,
    status: 'released',
    episodes: 37,
    episodesAired: 37,
    airedOn: ShikimoriAiredOnDto(
      year: 2006,
      month: 10,
      day: 4,
      date: '2006-10-04',
    ),
    poster: ShikimoriPosterDto(
      id: '100005',
      originalUrl: 'https://shikimori.one/posters/1535/original.jpg',
      mainUrl: 'https://shikimori.one/posters/1535/main.jpg',
    ),
  ),
];
