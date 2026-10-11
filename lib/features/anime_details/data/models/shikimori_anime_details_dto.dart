import 'package:iris/entities/anime/data/shikimori_anime_summary.dart';
import 'package:iris/entities/anime/domain/anime_summary.dart';

class ShikimoriAnimeDetailsDto {
  const ShikimoriAnimeDetailsDto({
    required this.anime,
    required this.description,
    this.rating = '',
    this.studios = const [],
    this.genres = const [],
    this.fandubbers = const [],
    this.related = const [],
  });

  /// With the original-size poster.
  final AnimeSummary anime;
  final String description;

  /// The age rating: `pg_13`, `r_plus`; `none` when unknown.
  final String rating;
  final List<String> studios;
  final List<ShikimoriDetailsGenreDto> genres;

  /// The dub teams.
  final List<String> fandubbers;
  final List<ShikimoriRelatedAnimeDto> related;

  /// Null when [json] has no anime; see [parseShikimoriAnimeSummary].
  static ShikimoriAnimeDetailsDto? tryParse(Map<String, dynamic> json) {
    final anime = parseShikimoriAnimeSummary(
      json,
      posterUrlField: 'originalUrl',
    );
    if (anime == null) return null;
    return ShikimoriAnimeDetailsDto(
      anime: anime,
      description: json['description']?.toString() ?? '',
      rating: json['rating']?.toString() ?? '',
      studios: [
        for (final studio in json['studios'] as List<dynamic>? ?? const [])
          if (studio case {'name': final String name}) name,
      ],
      genres: [
        for (final genre in json['genres'] as List<dynamic>? ?? const [])
          if (genre is Map<String, dynamic>)
            ShikimoriDetailsGenreDto.fromJson(genre),
      ],
      fandubbers: [
        for (final name in json['fandubbers'] as List<dynamic>? ?? const [])
          if (name is String && name.trim().isNotEmpty) name.trim(),
      ],
      related: [
        // Relations to manga and ranobe come without an anime.
        for (final item in json['related'] as List<dynamic>? ?? const [])
          ?ShikimoriRelatedAnimeDto.tryParse(item),
      ],
    );
  }
}

class ShikimoriDetailsGenreDto {
  const ShikimoriDetailsGenreDto({
    required this.name,
    required this.russian,
    required this.kind,
  });

  final String name;
  final String russian;

  /// `genre`, `demographic` or `theme`.
  final String kind;

  factory ShikimoriDetailsGenreDto.fromJson(Map<String, dynamic> json) {
    return ShikimoriDetailsGenreDto(
      name: json['name']?.toString() ?? '',
      russian: json['russian']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
    );
  }
}

class ShikimoriRelatedAnimeDto {
  const ShikimoriRelatedAnimeDto({
    required this.relationKind,
    required this.anime,
  });

  final String relationKind;
  final AnimeSummary anime;

  /// Null when [json] is not a relation to an anime.
  static ShikimoriRelatedAnimeDto? tryParse(Object? json) {
    if (json is! Map) return null;
    final anime = parseShikimoriAnimeSummary(json['anime']);
    if (anime == null) return null;
    return ShikimoriRelatedAnimeDto(
      relationKind: json['relationKind']?.toString() ?? '',
      anime: anime,
    );
  }
}
