import 'package:iris/entities/user_rate/data/user_rate_dto.dart';

class ShikimoriAnimeDto {
  const ShikimoriAnimeDto({
    required this.id,
    required this.malId,
    required this.name,
    required this.russian,
    this.english = '',
    required this.kind,
    required this.score,
    required this.status,
    required this.episodes,
    required this.episodesAired,
    required this.airedOn,
    required this.poster,
    this.userRate,
  });

  final String id;
  final String malId;
  final String name;
  final String russian;

  /// The licensed English title; empty when there is none.
  final String english;
  final String kind;
  final double score;
  final String status;
  final int episodes;
  final int episodesAired;
  final ShikimoriAiredOnDto airedOn;
  final ShikimoriPosterDto poster;

  /// The signed-in user's entry; null when signed out or not in the list.
  final UserRateDto? userRate;

  factory ShikimoriAnimeDto.fromJson(Map<String, dynamic> json) {
    return ShikimoriAnimeDto(
      id: json['id'].toString(),
      malId: json['malId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      russian: json['russian']?.toString() ?? '',
      english: json['english']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? '',
      episodes: (json['episodes'] as num?)?.toInt() ?? 0,
      episodesAired: (json['episodesAired'] as num?)?.toInt() ?? 0,
      airedOn: ShikimoriAiredOnDto.fromJson(
        json['airedOn'] as Map<String, dynamic>? ?? const {},
      ),
      poster: ShikimoriPosterDto.fromJson(
        json['poster'] as Map<String, dynamic>? ?? const {},
      ),
      userRate: UserRateDto.tryParse(json['userRate']),
    );
  }
}

class ShikimoriAiredOnDto {
  const ShikimoriAiredOnDto({
    required this.year,
    required this.month,
    required this.day,
    required this.date,
  });

  final int year;
  final int month;
  final int day;
  final String date;

  factory ShikimoriAiredOnDto.fromJson(Map<String, dynamic> json) {
    return ShikimoriAiredOnDto(
      year: (json['year'] as num?)?.toInt() ?? 0,
      month: (json['month'] as num?)?.toInt() ?? 0,
      day: (json['day'] as num?)?.toInt() ?? 0,
      date: json['date']?.toString() ?? '',
    );
  }
}

class ShikimoriPosterDto {
  const ShikimoriPosterDto({
    required this.id,
    required this.originalUrl,
    required this.mainUrl,
  });

  final String id;
  final String originalUrl;
  final String mainUrl;

  factory ShikimoriPosterDto.fromJson(Map<String, dynamic> json) {
    return ShikimoriPosterDto(
      id: json['id']?.toString() ?? '',
      originalUrl: json['originalUrl']?.toString() ?? '',
      mainUrl: json['mainUrl']?.toString() ?? '',
    );
  }
}
