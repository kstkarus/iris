import 'package:iris/features/anime_details/data/models/shikimori_anime_details_dto.dart';
import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/features/anime_details/domain/entities/anime_genre_name.dart';
import 'package:iris/features/anime_details/domain/entities/related_anime.dart';
import 'package:iris/shared/utils/shikimori_markup.dart';

AnimeDetails mapShikimoriAnimeDetailsToDomain(ShikimoriAnimeDetailsDto dto) {
  final anime = dto.anime;
  final normalizedEpisodesAired =
      anime.status == 'released' &&
          anime.episodes > 0 &&
          anime.episodesAired <= 0
      ? anime.episodes
      : anime.episodesAired;

  return AnimeDetails(
    anime: anime.copyWith(episodesAired: normalizedEpisodesAired),
    description: sanitizeShikimoriDescription(dto.description),
    rating: dto.rating == 'none' ? '' : dto.rating,
    studios: dto.studios,
    genres: [
      // Themes (school, military) are many and say little at a glance.
      for (final genre in dto.genres)
        if (genre.kind != 'theme' && genre.name.isNotEmpty)
          AnimeGenreName(name: genre.name, russian: genre.russian),
    ],
    fandubbers: dto.fandubbers,
    related: [
      for (final item in dto.related)
        RelatedAnime(
          relation: mapShikimoriRelation(item.relationKind),
          anime: item.anime,
        ),
    ],
  );
}

/// Kinds this app does not know yet read as [AnimeRelation.other].
AnimeRelation mapShikimoriRelation(String kind) => switch (kind) {
  'prequel' => AnimeRelation.prequel,
  'sequel' => AnimeRelation.sequel,
  'parent_story' => AnimeRelation.parentStory,
  'full_story' => AnimeRelation.fullStory,
  'side_story' => AnimeRelation.sideStory,
  'alternative_setting' => AnimeRelation.alternativeSetting,
  'alternative_version' => AnimeRelation.alternativeVersion,
  'spin_off' => AnimeRelation.spinOff,
  'summary' => AnimeRelation.summary,
  'character' => AnimeRelation.character,
  _ => AnimeRelation.other,
};
