import 'package:iris/features/anime_details/data/models/shikimori_anime_details_dto.dart';

class MockAnimeDetailsDataSource {
  Future<ShikimoriAnimeDetailsDto> fetchAnimeDetails(String id) async {
    final details = _animeDetails[id];

    if (details == null) {
      throw StateError('Anime details not found for id: $id');
    }

    return details;
  }
}

const _animeDetails = {
  '5114': ShikimoriAnimeDetailsDto(
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
    rating: 'r',
    studios: ['Bones'],
    genres: [
      ShikimoriDetailsGenreDto(name: 'Action', russian: 'Экшен', kind: 'genre'),
      ShikimoriDetailsGenreDto(
        name: 'Shounen',
        russian: 'Сёнен',
        kind: 'demographic',
      ),
      ShikimoriDetailsGenreDto(
        name: 'Military',
        russian: 'Военное',
        kind: 'theme',
      ),
    ],
    fandubbers: [
      'AniLibria',
      'AniDUB',
      'AniMedia',
      'SHIZA Project',
      'Studio Band',
      'Persona99',
      'Ancord',
      'JAM',
      'Cuba77',
      'Trina_D',
      'Absurd',
      'Eladiel',
      'Zendos',
      'Say',
      'Lupin',
    ],
  ),
  '52991': ShikimoriAnimeDetailsDto(
    id: '52991',
    malId: '52991',
    name: 'Frieren: Beyond Journey\'s End',
    russian: 'Frieren: Beyond Journey\'s End RU',
    description:
        'An immortal mage retraces her journey and learns what lingers after victory.',
    kind: 'tv',
    score: 9.27,
    status: 'released',
    episodes: 28,
    episodesAired: 28,
    airedOn: ShikimoriDetailsAiredOnDto(
      year: 2023,
      month: 9,
      day: 29,
      date: '2023-09-29',
    ),
    poster: ShikimoriDetailsPosterDto(
      id: 'poster-52991',
      originalUrl: 'https://shikimori.one/posters/52991/original.jpg',
    ),
  ),
  '9253': ShikimoriAnimeDetailsDto(
    id: '9253',
    malId: '9253',
    name: 'Steins;Gate',
    russian: 'Steins;Gate RU',
    description:
        'A self-proclaimed mad scientist discovers that messages can rewrite time.',
    kind: 'tv',
    score: 9.07,
    status: 'released',
    episodes: 24,
    episodesAired: 24,
    airedOn: ShikimoriDetailsAiredOnDto(
      year: 2011,
      month: 4,
      day: 6,
      date: '2011-04-06',
    ),
    poster: ShikimoriDetailsPosterDto(
      id: 'poster-9253',
      originalUrl: 'https://shikimori.one/posters/9253/original.jpg',
    ),
  ),
  '11061': ShikimoriAnimeDetailsDto(
    id: '11061',
    malId: '11061',
    name: 'Hunter x Hunter (2011)',
    russian: 'Hunter x Hunter (2011) RU',
    description:
        'Gon sets out to become a Hunter and find the father who chose adventure first.',
    kind: 'tv',
    score: 9.04,
    status: 'released',
    episodes: 148,
    episodesAired: 148,
    airedOn: ShikimoriDetailsAiredOnDto(
      year: 2011,
      month: 10,
      day: 2,
      date: '2011-10-02',
    ),
    poster: ShikimoriDetailsPosterDto(
      id: 'poster-11061',
      originalUrl: 'https://shikimori.one/posters/11061/original.jpg',
    ),
  ),
  '52299': ShikimoriAnimeDetailsDto(
    id: '52299',
    malId: '52299',
    name: 'Solo Leveling',
    russian: 'Solo Leveling RU',
    description:
        'The weakest hunter gains a system that lets him rise beyond every limit.',
    kind: 'tv',
    score: 8.34,
    status: 'released',
    episodes: 12,
    episodesAired: 12,
    airedOn: ShikimoriDetailsAiredOnDto(
      year: 2024,
      month: 1,
      day: 7,
      date: '2024-01-07',
    ),
    poster: ShikimoriDetailsPosterDto(
      id: 'poster-52299',
      originalUrl: 'https://shikimori.one/posters/52299/original.jpg',
    ),
  ),
  '1535': ShikimoriAnimeDetailsDto(
    id: '1535',
    malId: '1535',
    name: 'Death Note',
    russian: 'Death Note RU',
    description:
        'A notebook of death turns a brilliant student into a self-appointed judge.',
    kind: 'tv',
    score: 8.61,
    status: 'released',
    episodes: 37,
    episodesAired: 37,
    airedOn: ShikimoriDetailsAiredOnDto(
      year: 2006,
      month: 10,
      day: 4,
      date: '2006-10-04',
    ),
    poster: ShikimoriDetailsPosterDto(
      id: 'poster-1535',
      originalUrl: 'https://shikimori.one/posters/1535/original.jpg',
    ),
  ),
};
