import 'package:iris/features/online_sources/data/models/anilibria_episode_dto.dart';
import 'package:iris/shared/utils/json_read.dart';

/// A release as AniLibria's API gives it: a search result (no episodes) or
/// the full release.
class AnilibriaReleaseDto {
  const AnilibriaReleaseDto({
    required this.id,
    required this.title,
    this.shikimoriId,
    this.episodes = const [],
  });

  final int id;
  final String title;

  /// The Shikimori id AniLibria links the release to; null when unlinked.
  final int? shikimoriId;
  final List<AnilibriaEpisodeDto> episodes;

  factory AnilibriaReleaseDto.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final shikimori = json['shikimori'];
    final episodes = json['episodes'];
    return AnilibriaReleaseDto(
      id: jsonIntOrNull(json['id']) ?? 0,
      title: name is Map ? name['main']?.toString() ?? '' : '',
      shikimoriId: shikimori is Map ? jsonIntOrNull(shikimori['id']) : null,
      episodes: [
        if (episodes is List)
          for (final episode in episodes)
            if (episode is Map<String, dynamic>)
              AnilibriaEpisodeDto.fromJson(episode),
      ],
    );
  }
}
