class ShikimoriAnimeDetailsDto {
  const ShikimoriAnimeDetailsDto({
    required this.id,
    required this.malId,
    required this.name,
    required this.russian,
    required this.description,
    required this.kind,
    required this.score,
    required this.status,
    required this.episodes,
    required this.episodesAired,
    required this.airedOn,
    required this.poster,
  });

  final String id;
  final String malId;
  final String name;
  final String russian;
  final String description;
  final String kind;
  final double score;
  final String status;
  final int episodes;
  final int episodesAired;
  final ShikimoriDetailsAiredOnDto airedOn;
  final ShikimoriDetailsPosterDto poster;

  factory ShikimoriAnimeDetailsDto.fromJson(Map<String, dynamic> json) {
    return ShikimoriAnimeDetailsDto(
      id: json['id'].toString(),
      malId: json['malId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      russian: json['russian']?.toString() ?? '',
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
