import 'package:iris/features/online_sources/data/models/anilibria_episode_dto.dart';

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
      id: _int(json['id']) ?? 0,
      title: name is Map ? name['main']?.toString() ?? '' : '',
      shikimoriId: shikimori is Map ? _int(shikimori['id']) : null,
      episodes: [
        if (episodes is List)
          for (final episode in episodes)
            if (episode is Map<String, dynamic>)
              AnilibriaEpisodeDto.fromJson(episode),
      ],
    );
  }
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
