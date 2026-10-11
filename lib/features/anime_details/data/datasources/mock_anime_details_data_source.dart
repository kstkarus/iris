import 'package:iris/entities/anime/domain/anime_summary.dart';
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
    anime: AnimeSummary(
      id: '5114',
      name: 'Fullmetal Alchemist: Brotherhood',
      russian: 'Fullmetal Alchemist: Brotherhood RU',
      kind: 'tv',
      score: 9.12,
      status: 'released',
      episodes: 64,
      episodesAired: 64,
      airedOn: '2009-04-05',
      posterUrl: 'https://shikimori.one/posters/5114/original.jpg',
    ),
    description:
        'Two brothers search for a Philosopher\'s Stone after a failed ritual.',
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
    anime: AnimeSummary(
      id: '52991',
      name: 'Frieren: Beyond Journey\'s End',
      russian: 'Frieren: Beyond Journey\'s End RU',
      kind: 'tv',
      score: 9.27,
      status: 'released',
      episodes: 28,
      episodesAired: 28,
      airedOn: '2023-09-29',
      posterUrl: 'https://shikimori.one/posters/52991/original.jpg',
    ),
    description:
        'An immortal mage retraces her journey and learns what lingers after victory.',
  ),
  '9253': ShikimoriAnimeDetailsDto(
    anime: AnimeSummary(
      id: '9253',
      name: 'Steins;Gate',
      russian: 'Steins;Gate RU',
      kind: 'tv',
      score: 9.07,
      status: 'released',
      episodes: 24,
      episodesAired: 24,
      airedOn: '2011-04-06',
      posterUrl: 'https://shikimori.one/posters/9253/original.jpg',
    ),
    description:
        'A self-proclaimed mad scientist discovers that messages can rewrite time.',
  ),
  '11061': ShikimoriAnimeDetailsDto(
    anime: AnimeSummary(
      id: '11061',
      name: 'Hunter x Hunter (2011)',
      russian: 'Hunter x Hunter (2011) RU',
      kind: 'tv',
      score: 9.04,
      status: 'released',
      episodes: 148,
      episodesAired: 148,
      airedOn: '2011-10-02',
      posterUrl: 'https://shikimori.one/posters/11061/original.jpg',
    ),
    description:
        'Gon sets out to become a Hunter and find the father who chose adventure first.',
  ),
  '52299': ShikimoriAnimeDetailsDto(
    anime: AnimeSummary(
      id: '52299',
      name: 'Solo Leveling',
      russian: 'Solo Leveling RU',
      kind: 'tv',
      score: 8.34,
      status: 'released',
      episodes: 12,
      episodesAired: 12,
      airedOn: '2024-01-07',
      posterUrl: 'https://shikimori.one/posters/52299/original.jpg',
    ),
    description:
        'The weakest hunter gains a system that lets him rise beyond every limit.',
  ),
  '1535': ShikimoriAnimeDetailsDto(
    anime: AnimeSummary(
      id: '1535',
      name: 'Death Note',
      russian: 'Death Note RU',
      kind: 'tv',
      score: 8.61,
      status: 'released',
      episodes: 37,
      episodesAired: 37,
      airedOn: '2006-10-04',
      posterUrl: 'https://shikimori.one/posters/1535/original.jpg',
    ),
    description:
        'A notebook of death turns a brilliant student into a self-appointed judge.',
  ),
};
