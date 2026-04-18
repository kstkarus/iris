import 'package:iris/features/anime_details/data/models/shikimori_anime_details_dto.dart';
import 'package:iris/features/anime_details/domain/entities/anime_details.dart';

AnimeDetails mapShikimoriAnimeDetailsToDomain(ShikimoriAnimeDetailsDto dto) {
  final normalizedEpisodesAired =
      dto.status == 'released' && dto.episodes > 0 && dto.episodesAired <= 0
      ? dto.episodes
      : dto.episodesAired;

  return AnimeDetails(
    id: dto.id,
    name: dto.name,
    russian: dto.russian,
    description: sanitizeShikimoriDescription(dto.description),
    kind: dto.kind,
    score: dto.score,
    status: dto.status,
    episodes: dto.episodes,
    episodesAired: normalizedEpisodesAired,
    airedOn: dto.airedOn.date,
    posterOriginalUrl: dto.poster.originalUrl,
  );
}

String sanitizeShikimoriDescription(String input) {
  final linkedTagPattern = RegExp(
    r'\[(\w+)(=[^\]]+)?\](.*?)\[/\1\]',
    dotAll: true,
  );
  final remainingTagPattern = RegExp(r'\[/?[^\]]+\]');
  final extraSpacesBeforeNewlinePattern = RegExp(r'[ \t]+\n');
  final excessiveNewLinesPattern = RegExp(r'\n{3,}');

  final withoutLinkedTags = input.replaceAllMapped(
    linkedTagPattern,
    (match) => match.group(3) ?? '',
  );
  final withoutRemainingTags = withoutLinkedTags.replaceAll(
    remainingTagPattern,
    '',
  );
  final normalizedLineEndings = withoutRemainingTags.replaceAll('\r\n', '\n');
  final withoutTrailingSpaces = normalizedLineEndings.replaceAll(
    extraSpacesBeforeNewlinePattern,
    '\n',
  );

  return withoutTrailingSpaces
      .replaceAll(excessiveNewLinesPattern, '\n\n')
      .trim();
}
