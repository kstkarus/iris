/// An anime as yummy_anime's search gives it.
class YummyAnimeDto {
  const YummyAnimeDto({
    required this.animeId,
    required this.title,
    this.shikimoriId,
  });

  final int animeId;
  final String title;

  /// The Shikimori id yummy_anime links the anime to; null when unlinked.
  final int? shikimoriId;

  factory YummyAnimeDto.fromJson(Map<String, dynamic> json) {
    final remoteIds = json['remote_ids'];
    final shikimoriId = remoteIds is Map
        ? _int(remoteIds['shikimori_id'])
        : null;
    return YummyAnimeDto(
      animeId: _int(json['anime_id']) ?? 0,
      title: json['title']?.toString() ?? '',
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
      durationSeconds: _int(json['duration']),
      views: _int(json['views']) ?? 0,
    );
  }
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
