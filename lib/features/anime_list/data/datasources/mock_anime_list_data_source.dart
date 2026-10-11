import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/anime_list/data/models/shikimori_anime_dto.dart';

class MockAnimeListDataSource {
  Future<List<ShikimoriAnimeDto>> fetchPopularAnime() async {
    return _anime;
  }
}

const _anime = [
  ShikimoriAnimeDto(
    anime: AnimeSummary(
      id: '5114',
      name: 'Fullmetal Alchemist: Brotherhood',
      russian: 'Стальной алхимик: Братство',
      kind: 'tv',
      score: 9.12,
      status: 'released',
      episodes: 64,
      episodesAired: 64,
      airedOn: '2009-04-05',
      posterUrl: 'https://shikimori.one/posters/5114/main.jpg',
    ),
  ),
  ShikimoriAnimeDto(
    anime: AnimeSummary(
      id: '52991',
      name: 'Frieren: Beyond Journey\'s End',
      russian: 'Провожающая в последний путь Фрирен',
      kind: 'tv',
      score: 9.27,
      status: 'released',
      episodes: 28,
      episodesAired: 28,
      airedOn: '2023-09-29',
      posterUrl: 'https://shikimori.one/posters/52991/main.webp',
    ),
  ),
  ShikimoriAnimeDto(
    anime: AnimeSummary(
      id: '9253',
      name: 'Steins;Gate',
      russian: 'Врата Штейна',
      kind: 'tv',
      score: 9.07,
      status: 'released',
      episodes: 24,
      episodesAired: 24,
      airedOn: '2011-04-06',
      posterUrl: 'https://shikimori.one/posters/9253/main.jpg',
    ),
  ),
  ShikimoriAnimeDto(
    anime: AnimeSummary(
      id: '11061',
      name: 'Hunter x Hunter (2011)',
      russian: 'Охотник х Охотник',
      kind: 'tv',
      score: 9.04,
      status: 'released',
      episodes: 148,
      episodesAired: 148,
      airedOn: '2011-10-02',
      posterUrl: 'https://shikimori.one/posters/11061/main.jpg',
    ),
  ),
  ShikimoriAnimeDto(
    anime: AnimeSummary(
      id: '52299',
      name: 'Solo Leveling',
      russian: 'Поднятие уровня в одиночку',
      kind: 'tv',
      score: 8.34,
      status: 'released',
      episodes: 12,
      episodesAired: 12,
      airedOn: '2024-01-07',
      posterUrl: 'https://shikimori.one/posters/52299/main.webp',
    ),
  ),
  ShikimoriAnimeDto(
    anime: AnimeSummary(
      id: '1535',
      name: 'Death Note',
      russian: 'Тетрадь смерти',
      kind: 'tv',
      score: 8.61,
      status: 'released',
      episodes: 37,
      episodesAired: 37,
      airedOn: '2006-10-04',
      posterUrl: 'https://shikimori.one/posters/1535/main.jpg',
    ),
  ),
];
