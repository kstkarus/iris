import 'package:iris/features/anime_list/domain/entities/anime_genre.dart';

abstract interface class AnimeGenresRepository {
  /// Every anime genre, theme and audience Shikimori filters by.
  Future<List<AnimeGenre>> genres();
}
