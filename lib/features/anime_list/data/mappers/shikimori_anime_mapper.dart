import 'package:iris/features/anime_list/data/models/shikimori_anime_dto.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';

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
    airedOn: dto.airedOn.date,
    posterMainUrl: dto.poster.mainUrl,
  );
}
