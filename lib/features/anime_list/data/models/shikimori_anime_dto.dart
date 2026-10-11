import 'package:iris/entities/anime/data/shikimori_anime_summary.dart';
import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/entities/user_rate/data/user_rate_dto.dart';

class ShikimoriAnimeDto {
  const ShikimoriAnimeDto({required this.anime, this.userRate});

  final AnimeSummary anime;

  /// The signed-in user's entry; null when signed out or not in the list.
  final UserRateDto? userRate;

  /// Null when [json] is not an anime; see [parseShikimoriAnimeSummary].
  static ShikimoriAnimeDto? tryParse(Object? json) {
    if (json is! Map) return null;
    final anime = parseShikimoriAnimeSummary(json);
    if (anime == null) return null;
    return ShikimoriAnimeDto(
      anime: anime,
      userRate: UserRateDto.tryParse(json['userRate']),
    );
  }
}
