import 'package:iris/entities/user_rate/domain/user_rate.dart';

/// The signed-in user's Shikimori list, one anime at a time.
abstract interface class UserRateRepository {
  /// Null when the anime is not in the list.
  Future<UserRate?> fetch(String animeId);

  /// Adds the anime to [userId]'s list, or changes the entry [rateId].
  /// Returns the entry as Shikimori keeps it (it may finish the anime
  /// when the last episode is marked).
  Future<UserRate> save({
    required String userId,
    required String animeId,
    required String? rateId,
    required UserRateStatus status,
    required int episodes,
  });

  Future<void> remove(String rateId);
}
