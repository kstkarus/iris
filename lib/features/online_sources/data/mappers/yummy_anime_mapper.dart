import 'package:iris/features/online_sources/data/models/yummy_anime_dto.dart';
import 'package:iris/features/online_sources/domain/entities/online_episode.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';

/// The players this app can read; yummy_anime also embeds CVH and Alloha,
/// which anicli-api cannot read reliably either.
enum YummyPlayer {
  /// DASH up to 1080, for a few dubs.
  aksor,

  /// HLS up to 720, for nearly every dub.
  kodik;

  static YummyPlayer? of(String iframeUrl) {
    final host = Uri.tryParse(iframeUrl)?.host ?? '';
    if (host.contains('aksor')) return aksor;
    if (host.contains('kodik')) return kodik;
    return null;
  }
}

/// One release per dub: its episodes by number, each episode's id being
/// its player pages, the better player first.
///
/// A release id is `<anime id>:<dub>` (dub URL-encoded), so a release is
/// found again from the videos of its anime.
List<OnlineRelease> mapYummyReleases({
  required int animeId,
  required List<YummyVideoDto> videos,
}) {
  final byDub = <String, List<YummyVideoDto>>{};
  final views = <String, int>{};
  for (final video in videos) {
    if (video.dubbing.isEmpty || YummyPlayer.of(video.iframeUrl) == null) {
      continue;
    }
    (byDub[video.dubbing] ??= []).add(video);
    views[video.dubbing] = (views[video.dubbing] ?? 0) + video.views;
  }
  // The most watched dubs first: the ones people pick.
  final dubs = byDub.keys.toList()
    ..sort((left, right) => views[right]!.compareTo(views[left]!));
  return [
    for (final dub in dubs)
      _release(animeId: animeId, dub: dub, videos: byDub[dub]!),
  ];
}

/// The release [releaseId] among an anime's [videos], or null.
OnlineRelease? findYummyRelease({
  required String releaseId,
  required List<YummyVideoDto> videos,
}) {
  final parts = parseYummyReleaseId(releaseId);
  if (parts == null) return null;
  final matching = [
    for (final video in videos)
      if (video.dubbing == parts.dub && YummyPlayer.of(video.iframeUrl) != null)
        video,
  ];
  if (matching.isEmpty) return null;
  return _release(animeId: parts.animeId, dub: parts.dub, videos: matching);
}

({int animeId, String dub})? parseYummyReleaseId(String releaseId) {
  final colon = releaseId.indexOf(':');
  if (colon <= 0) return null;
  final animeId = int.tryParse(releaseId.substring(0, colon));
  final dub = Uri.decodeComponent(releaseId.substring(colon + 1));
  if (animeId == null || dub.isEmpty) return null;
  return (animeId: animeId, dub: dub);
}

OnlineRelease _release({
  required int animeId,
  required String dub,
  required List<YummyVideoDto> videos,
}) {
  final byNumber = <num, List<YummyVideoDto>>{};
  for (final video in videos) {
    final number = num.tryParse(video.number);
    if (number == null) continue;
    (byNumber[number] ??= []).add(video);
  }
  final numbers = byNumber.keys.toList()..sort();
  final hasAksor = videos.any(
    (video) => YummyPlayer.of(video.iframeUrl) == YummyPlayer.aksor,
  );
  return OnlineRelease(
    provider: OnlineProvider.yummyAnime,
    id: '$animeId:${Uri.encodeComponent(dub)}',
    dub: yummyDubLabel(dub),
    episodes: [
      for (final number in numbers)
        _episode(number: number, videos: byNumber[number]!),
    ],
    // Aksor serves 1080, Kodik 720.
    bestQuality: hasAksor ? 1080 : 720,
  );
}

OnlineEpisode _episode({
  required num number,
  required List<YummyVideoDto> videos,
}) {
  final players = [...videos]
    ..sort(
      (left, right) => YummyPlayer.of(
        left.iframeUrl,
      )!.index.compareTo(YummyPlayer.of(right.iframeUrl)!.index),
    );
  final seconds = videos
      .map((video) => video.durationSeconds ?? 0)
      .fold(0, (longest, value) => value > longest ? value : longest);
  return OnlineEpisode(
    id: encodeYummyEpisodeId([for (final video in players) video.iframeUrl]),
    number: number,
    duration: seconds > 0 ? Duration(seconds: seconds) : null,
  );
}

/// An episode's player pages, which never hold spaces, as one id.
String encodeYummyEpisodeId(List<String> playerUrls) => playerUrls.join(' ');

List<String> decodeYummyEpisodeId(String episodeId) => [
  for (final url in episodeId.split(' '))
    if (url.isNotEmpty) url,
];

/// "Озвучка AniDUB" reads "AniDUB" under the "Online" label; subtitles
/// keep their word, as they are not a voice.
String yummyDubLabel(String dubbing) {
  const voice = 'Озвучка ';
  return dubbing.startsWith(voice)
      ? dubbing.substring(voice.length).trim()
      : dubbing;
}
