import 'package:iris/entities/user_rate/domain/user_rate.dart';

/// The signed-in user's Shikimori list, one anime at a time.
abstract interface class UserRateRepository {
  /// Every entry read, saved or removed, so screens showing the same
  /// anime agree.
  Stream<UserRateChange> get changes;

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
    required int score,
  });

  /// Takes the entry [rateId] of [animeId] out of the list.
  Future<void> remove({required String animeId, required String rateId});
}
