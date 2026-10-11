import 'package:iris/features/online_sources/data/models/anilibria_episode_dto.dart';
import 'package:iris/features/online_sources/data/models/anilibria_release_dto.dart';
import 'package:iris/features/online_sources/domain/entities/online_episode.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';

/// AniLibria voices its releases itself.
const anilibriaDub = 'AniLibria';

OnlineRelease mapAnilibriaRelease(AnilibriaReleaseDto release) {
  final episodes = [...release.episodes]
    ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
  return OnlineRelease(
    provider: OnlineProvider.anilibria,
    id: '${release.id}',
    dub: anilibriaDub,
    // An episode without streams (blocked, not uploaded) cannot play.
    episodes: [
      for (final episode in episodes)
        if (episode.id.isNotEmpty && mapAnilibriaStreams(episode).isNotEmpty)
          mapAnilibriaEpisode(episode),
    ],
    bestQuality: _bestQuality(episodes),
  );
}

int? _bestQuality(List<AnilibriaEpisodeDto> episodes) {
  int? best;
  for (final episode in episodes) {
    final streams = mapAnilibriaStreams(episode);
    if (streams.isEmpty) continue;
    final quality = streams.first.quality;
    if (best == null || quality > best) best = quality;
  }
  return best;
}

OnlineEpisode mapAnilibriaEpisode(AnilibriaEpisodeDto episode) {
  final seconds = episode.durationSeconds;
  return OnlineEpisode(
    id: episode.id,
    number: episode.ordinal,
    title: episode.name ?? '',
    duration: seconds == null || seconds <= 0
        ? null
        : Duration(seconds: seconds),
  );
}

/// Best quality first.
List<OnlineStream> mapAnilibriaStreams(AnilibriaEpisodeDto episode) {
  return [
    for (final (quality, url) in [
      (1080, episode.hls1080),
      (720, episode.hls720),
      (480, episode.hls480),
    ])
      if (url != null)
        OnlineStream(
          url: url,
          quality: quality,
          format: OnlineStreamFormat.hls,
        ),
  ];
}
