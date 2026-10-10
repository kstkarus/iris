import 'package:iris/entities/user_rate/domain/user_rate.dart';

/// A user rate as both Shikimori APIs give it: `userRate` in GraphQL and
/// the `/api/v2/user_rates` body.
class UserRateDto {
  const UserRateDto({
    required this.id,
    required this.status,
    required this.episodes,
    required this.score,
  });

  /// Null when [json] is not a rate or its status is unknown.
  static UserRateDto? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final status = statusFromApi(json['status']);
    final episodes = json['episodes'];
    final score = json['score'];
    if (id == null || status == null) return null;
    return UserRateDto(
      id: '$id',
      status: status,
      episodes: episodes is num ? episodes.toInt() : 0,
      score: score is num ? score.toInt() : 0,
    );
  }

  final String id;
  final UserRateStatus status;
  final int episodes;
  final int score;

  UserRate toEntity() =>
      UserRate(id: id, status: status, episodes: episodes, score: score);

  static UserRateStatus? statusFromApi(Object? value) => switch (value) {
    'planned' => UserRateStatus.planned,
    'watching' => UserRateStatus.watching,
    'rewatching' => UserRateStatus.rewatching,
    'completed' => UserRateStatus.completed,
    'on_hold' => UserRateStatus.onHold,
    'dropped' => UserRateStatus.dropped,
    _ => null,
  };

  static String statusToApi(UserRateStatus status) => switch (status) {
    UserRateStatus.planned => 'planned',
    UserRateStatus.watching => 'watching',
    UserRateStatus.rewatching => 'rewatching',
    UserRateStatus.completed => 'completed',
    UserRateStatus.onHold => 'on_hold',
    UserRateStatus.dropped => 'dropped',
  };
}
