import 'package:iris/entities/user_rate/data/user_rate_dto.dart';
import 'package:iris/features/profile/domain/entities/user_list_entry.dart';
import 'package:iris/shared/utils/incomplete_date.dart';

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
    final airedOn = _map(json['airedOn']);
    return ListedAnime(
      id: '$id',
      name: _string(json['name']),
      russian: _string(json['russian']),
      kind: _string(json['kind']),
      score: _number(json['score']).toDouble(),
      status: _string(json['status']),
      episodes: _number(json['episodes']).toInt(),
      episodesAired: _number(json['episodesAired']).toInt(),
      airedOn: incompleteIsoDate(
        year: _number(airedOn['year']).toInt(),
        month: _number(airedOn['month']).toInt(),
        day: _number(airedOn['day']).toInt(),
        date: _string(airedOn['date']),
      ),
      posterUrl: _string(_map(json['poster'])['mainUrl']),
      nextEpisodeAt: DateTime.tryParse(_string(json['nextEpisodeAt'])),
    );
  }

  static Map<Object?, Object?> _map(Object? value) =>
      value is Map ? value : const {};

  static String _string(Object? value) => value is String ? value : '';

  static num _number(Object? value) => value is num ? value : 0;
}
