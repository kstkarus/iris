import 'package:iris/features/anime_details/data/models/shikimori_anime_details_dto.dart';
import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/features/anime_details/domain/entities/related_anime.dart';
import 'package:iris/shared/utils/incomplete_date.dart';

AnimeDetails mapShikimoriAnimeDetailsToDomain(ShikimoriAnimeDetailsDto dto) {
  final normalizedEpisodesAired =
      dto.status == 'released' && dto.episodes > 0 && dto.episodesAired <= 0
      ? dto.episodes
      : dto.episodesAired;

  return AnimeDetails(
    id: dto.id,
    name: dto.name,
    russian: dto.russian,
    english: dto.english,
    description: sanitizeShikimoriDescription(dto.description),
    kind: dto.kind,
    score: dto.score,
    status: dto.status,
    episodes: dto.episodes,
    episodesAired: normalizedEpisodesAired,
    airedOn: _airedOn(dto.airedOn),
    posterOriginalUrl: dto.poster.originalUrl,
    related: [for (final item in dto.related) _mapRelated(item)],
  );
}

RelatedAnime _mapRelated(ShikimoriRelatedAnimeDto dto) => RelatedAnime(
  relation: mapShikimoriRelation(dto.relationKind),
  id: dto.id,
  name: dto.name,
  russian: dto.russian,
  english: dto.english,
  kind: dto.kind,
  score: dto.score,
  status: dto.status,
  episodes: dto.episodes,
  episodesAired: dto.episodesAired,
  airedOn: _airedOn(dto.airedOn),
  posterUrl: dto.posterMainUrl,
);

String _airedOn(ShikimoriDetailsAiredOnDto date) => incompleteIsoDate(
  year: date.year,
  month: date.month,
  day: date.day,
  date: date.date,
);

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

String sanitizeShikimoriDescription(String input) {
  // Wiki links: [[Page]] or [[Page|shown text]].
  final wikiLinkPattern = RegExp(r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]');
  final linkedTagPattern = RegExp(
    r'\[(\w+)(=[^\]]+)?\](.*?)\[/\1\]',
    dotAll: true,
  );
  final remainingTagPattern = RegExp(r'\[/?[^\]]+\]');
  final extraSpacesBeforeNewlinePattern = RegExp(r'[ \t]+\n');
  final excessiveNewLinesPattern = RegExp(r'\n{3,}');
  final repeatedSpacesPattern = RegExp(r'[ \t]{2,}');

  final withoutWikiLinks = input.replaceAllMapped(
    wikiLinkPattern,
    (match) => match.group(2) ?? match.group(1) ?? '',
  );
  final withoutLinkedTags = withoutWikiLinks.replaceAllMapped(
    linkedTagPattern,
    (match) => match.group(3) ?? '',
  );
  final withoutRemainingTags = withoutLinkedTags.replaceAll(
    remainingTagPattern,
    '',
  );
  final normalizedLineEndings = withoutRemainingTags.replaceAll('\r\n', '\n');
  final withoutTrailingSpaces = normalizedLineEndings
      .replaceAll(repeatedSpacesPattern, ' ')
      .replaceAll(extraSpacesBeforeNewlinePattern, '\n');

  return withoutTrailingSpaces
      .replaceAll(excessiveNewLinesPattern, '\n\n')
      .trim();
}
