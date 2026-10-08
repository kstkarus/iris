class ShikimoriAnimeDetailsDto {
  const ShikimoriAnimeDetailsDto({
    required this.id,
    required this.malId,
    required this.name,
    required this.russian,
    this.english = '',
    required this.description,
    required this.kind,
    required this.score,
    required this.status,
    required this.episodes,
    required this.episodesAired,
    required this.airedOn,
    required this.poster,
    this.related = const [],
  });

  final String id;
  final String malId;
  final String name;
  final String russian;

  /// The licensed English title; empty when there is none.
  final String english;
  final String description;
  final String kind;
  final double score;
  final String status;
  final int episodes;
  final int episodesAired;
  final ShikimoriDetailsAiredOnDto airedOn;
  final ShikimoriDetailsPosterDto poster;
  final List<ShikimoriRelatedAnimeDto> related;

  factory ShikimoriAnimeDetailsDto.fromJson(Map<String, dynamic> json) {
    return ShikimoriAnimeDetailsDto(
      id: json['id'].toString(),
      malId: json['malId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      russian: json['russian']?.toString() ?? '',
      english: json['english']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? '',
      episodes: (json['episodes'] as num?)?.toInt() ?? 0,
      episodesAired: (json['episodesAired'] as num?)?.toInt() ?? 0,
      airedOn: ShikimoriDetailsAiredOnDto.fromJson(
        json['airedOn'] as Map<String, dynamic>? ?? const {},
      ),
      poster: ShikimoriDetailsPosterDto.fromJson(
        json['poster'] as Map<String, dynamic>? ?? const {},
      ),
      related: [
        // Relations to manga and ranobe come without an anime.
        for (final item in json['related'] as List<dynamic>? ?? const [])
          if (item case {'anime': final Map<String, dynamic> _})
            ShikimoriRelatedAnimeDto.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class ShikimoriRelatedAnimeDto {
  const ShikimoriRelatedAnimeDto({
    required this.relationKind,
    required this.id,
    required this.name,
    required this.russian,
    required this.english,
    required this.kind,
    required this.score,
    required this.status,
    required this.episodes,
    required this.episodesAired,
    required this.airedOn,
    required this.posterMainUrl,
  });

  final String relationKind;
  final String id;
  final String name;
  final String russian;
  final String english;
  final String kind;
  final double score;
  final String status;
  final int episodes;
  final int episodesAired;
  final ShikimoriDetailsAiredOnDto airedOn;
  final String posterMainUrl;

  factory ShikimoriRelatedAnimeDto.fromJson(Map<String, dynamic> json) {
    final anime = json['anime'] as Map<String, dynamic>;
    final airedOn = anime['airedOn'] as Map<String, dynamic>? ?? const {};
    final poster = anime['poster'] as Map<String, dynamic>? ?? const {};
    return ShikimoriRelatedAnimeDto(
      relationKind: json['relationKind']?.toString() ?? '',
      id: anime['id'].toString(),
      name: anime['name']?.toString() ?? '',
      russian: anime['russian']?.toString() ?? '',
      english: anime['english']?.toString() ?? '',
      kind: anime['kind']?.toString() ?? '',
      score: (anime['score'] as num?)?.toDouble() ?? 0,
      status: anime['status']?.toString() ?? '',
      episodes: (anime['episodes'] as num?)?.toInt() ?? 0,
      episodesAired: (anime['episodesAired'] as num?)?.toInt() ?? 0,
      airedOn: ShikimoriDetailsAiredOnDto.fromJson(airedOn),
      posterMainUrl: poster['mainUrl']?.toString() ?? '',
    );
  }
}

class ShikimoriDetailsAiredOnDto {
  const ShikimoriDetailsAiredOnDto({
    required this.year,
    required this.month,
    required this.day,
    required this.date,
  });

  final int year;
  final int month;
  final int day;
  final String date;

  factory ShikimoriDetailsAiredOnDto.fromJson(Map<String, dynamic> json) {
    return ShikimoriDetailsAiredOnDto(
      year: (json['year'] as num?)?.toInt() ?? 0,
      month: (json['month'] as num?)?.toInt() ?? 0,
      day: (json['day'] as num?)?.toInt() ?? 0,
      date: json['date']?.toString() ?? '',
    );
  }
}

class ShikimoriDetailsPosterDto {
  const ShikimoriDetailsPosterDto({
    required this.id,
    required this.originalUrl,
  });

  final String id;
  final String originalUrl;

  factory ShikimoriDetailsPosterDto.fromJson(Map<String, dynamic> json) {
    return ShikimoriDetailsPosterDto(
      id: json['id']?.toString() ?? '',
      originalUrl: json['originalUrl']?.toString() ?? '',
    );
  }
}
