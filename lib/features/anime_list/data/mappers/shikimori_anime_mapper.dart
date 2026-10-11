import 'package:iris/features/anime_list/data/models/shikimori_anime_dto.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';

AnimeListItem mapShikimoriAnimeToDomain(ShikimoriAnimeDto dto) =>
    AnimeListItem(anime: dto.anime, userRate: dto.userRate?.toEntity());
