import 'package:iris/features/anime_list/data/models/shikimori_anime_dto.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/shared/utils/incomplete_date.dart';

AnimeListItem mapShikimoriAnimeToDomain(ShikimoriAnimeDto dto) {
  return AnimeListItem(
    id: dto.id,
    name: dto.name,
    russian: dto.russian,
    english: dto.english,
    kind: dto.kind,
    score: dto.score,
    status: dto.status,
    episodes: dto.episodes,
    episodesAired: dto.episodesAired,
    airedOn: incompleteIsoDate(
      year: dto.airedOn.year,
      month: dto.airedOn.month,
      day: dto.airedOn.day,
      date: dto.airedOn.date,
    ),
    posterMainUrl: dto.poster.mainUrl,
  );
}
