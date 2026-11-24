import 'package:iris/features/player/data/models/tenrai_episode_dto.dart';
import 'package:iris/features/player/domain/entities/episode_metadata.dart';

EpisodeMetadata? mapTenraiEpisode(TenraiEpisodeDto dto) {
  final number = dto.number;
  if (number == null || number <= 0) return null;
  final title = dto.title.trim();
  final metadata = EpisodeMetadata(
    number: number,
    title: title.isEmpty ? null : title,
    filler: dto.filler,
    recap: dto.recap,
  );
  return metadata.isEmpty ? null : metadata;
}
