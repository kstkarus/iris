import 'package:iris/features/anime_list/domain/entities/anime_genre.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_genres_repository.dart';

/// A few of Shikimori's genres, with their real ids.
class MockAnimeGenresRepository implements AnimeGenresRepository {
  const MockAnimeGenresRepository();

  static const all = [
    AnimeGenre(
      id: '1',
      name: 'Action',
      russian: 'Экшен',
      kind: AnimeGenreKind.genre,
    ),
    AnimeGenre(
      id: '2',
      name: 'Adventure',
      russian: 'Приключения',
      kind: AnimeGenreKind.genre,
    ),
    AnimeGenre(
      id: '10',
      name: 'Fantasy',
      russian: 'Фэнтези',
      kind: AnimeGenreKind.genre,
    ),
    AnimeGenre(
      id: '27',
      name: 'Shounen',
      russian: 'Сёнен',
      kind: AnimeGenreKind.demographic,
    ),
    AnimeGenre(
      id: '38',
      name: 'Military',
      russian: 'Военное',
      kind: AnimeGenreKind.theme,
    ),
  ];

  @override
  Future<List<AnimeGenre>> genres() async => all;
}
