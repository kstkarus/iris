import 'package:iris/entities/user_rate/data/user_rate_dto.dart';
import 'package:iris/features/profile/domain/entities/user_list_entry.dart';
import 'package:iris/shared/utils/incomplete_date.dart';
import 'package:iris/shared/utils/json_read.dart';

/// One `userRates` item of the GraphQL API, with its anime.
abstract final class UserListEntryDto {
  /// Null when [json] is not an entry, its status is unknown or its anime
  /// is gone.
  static UserListEntry? tryParse(Object? json) {
    if (json is! Map) return null;
    final rate = UserRateDto.tryParse(json)?.toEntity();
    final anime = _anime(json['anime']);
    if (rate == null || anime == null) return null;
    return UserListEntry(rate: rate, anime: anime);
  }

  static ListedAnime? _anime(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id == null) return null;
    final airedOn = jsonMap(json['airedOn']);
    return ListedAnime(
      id: '$id',
      name: jsonString(json['name']),
      russian: jsonString(json['russian']),
      kind: jsonString(json['kind']),
      score: jsonNum(json['score']).toDouble(),
      status: jsonString(json['status']),
      episodes: jsonInt(json['episodes']),
      episodesAired: jsonInt(json['episodesAired']),
      airedOn: incompleteIsoDate(
        year: jsonInt(airedOn['year']),
        month: jsonInt(airedOn['month']),
        day: jsonInt(airedOn['day']),
        date: jsonString(airedOn['date']),
      ),
      posterUrl: jsonString(jsonMap(json['poster'])['mainUrl']),
      nextEpisodeAt: DateTime.tryParse(jsonString(json['nextEpisodeAt'])),
    );
  }
}
