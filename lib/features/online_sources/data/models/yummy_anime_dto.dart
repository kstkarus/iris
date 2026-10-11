import 'package:iris/shared/utils/json_read.dart';

/// An anime as yummy_anime's search gives it.
class YummyAnimeDto {
  const YummyAnimeDto({required this.animeId, this.shikimoriId});

  final int animeId;

  /// The Shikimori id yummy_anime links the anime to; null when unlinked.
  final int? shikimoriId;

  factory YummyAnimeDto.fromJson(Map<String, dynamic> json) {
    final remoteIds = json['remote_ids'];
    final shikimoriId = remoteIds is Map
        ? jsonIntOrNull(remoteIds['shikimori_id'])
        : null;
    return YummyAnimeDto(
      animeId: jsonIntOrNull(json['anime_id']) ?? 0,
      // yummy_anime writes 0 for "not linked".
      shikimoriId: shikimoriId == 0 ? null : shikimoriId,
    );
  }
}

/// One video of an anime: an episode in one dub, behind one player.
class YummyVideoDto {
  const YummyVideoDto({
    required this.number,
    required this.dubbing,
    required this.iframeUrl,
    this.durationSeconds,
    this.views = 0,
  });

  /// The episode's number as written, e.g. "12" (rarely "12.5").
  final String number;

  /// Who voiced it, as yummy_anime labels it: "Озвучка AniDUB",
  /// "Субтитры Crunchyroll".
  final String dubbing;

  /// The player's page, with a scheme.
  final String iframeUrl;
  final int? durationSeconds;
  final int views;

  factory YummyVideoDto.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final iframe = json['iframe_url']?.toString().trim() ?? '';
    return YummyVideoDto(
      number: json['number']?.toString().trim() ?? '',
      dubbing: data is Map ? data['dubbing']?.toString().trim() ?? '' : '',
      iframeUrl: iframe.startsWith('//') ? 'https:$iframe' : iframe,
      durationSeconds: jsonIntOrNull(json['duration']),
      views: jsonIntOrNull(json['views']) ?? 0,
    );
  }
}
