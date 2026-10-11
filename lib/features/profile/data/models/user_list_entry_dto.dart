import 'package:iris/entities/anime/data/shikimori_anime_summary.dart';
import 'package:iris/entities/user_rate/data/user_rate_dto.dart';
import 'package:iris/features/profile/domain/entities/user_list_entry.dart';

/// One `userRates` item of the GraphQL API, with its anime.
abstract final class UserListEntryDto {
  /// Null when [json] is not an entry, its status is unknown or its anime
  /// is gone.
  static UserListEntry? tryParse(Object? json) {
    if (json is! Map) return null;
    final rate = UserRateDto.tryParse(json)?.toEntity();
    final anime = parseShikimoriAnimeSummary(json['anime']);
    if (rate == null || anime == null) return null;
    return UserListEntry(rate: rate, anime: anime);
  }
}
