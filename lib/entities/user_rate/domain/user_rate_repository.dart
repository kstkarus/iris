import 'package:iris/entities/user_rate/domain/user_rate.dart';

/// The signed-in user's Shikimori list, one anime at a time.
abstract interface class UserRateRepository {
  /// Every entry read, saved or removed, so screens showing the same
  /// anime agree. Confirmed writes are emitted as [UserRateMutation].
  Stream<UserRateChange> get changes;

  /// Null when the anime is not in the list.
  Future<UserRate?> fetch(String animeId);

  /// [fetch], with the anime's episode count as Shikimori has it: 0 while
  /// unknown, as for many airing anime.
  Future<({UserRate? rate, int totalEpisodes})> fetchWithTotal(String animeId);

  /// Keeps a read and its dependent edit together in the request queue and
  /// in the original account session. Use the supplied repository in [edit].
  Future<T> editRate<T>(Future<T> Function(UserRateRepository) edit);

  /// Adds the anime to [userId]'s list, or changes the entry [rateId].
  /// Returns the entry as Shikimori keeps it (it may finish the anime
  /// when the last episode is marked). Omitted fields stay unchanged on update.
  Future<UserRate> save({
    required String userId,
    required String animeId,
    required String? rateId,
    UserRateStatus? status,
    int? episodes,
    int? score,
    int? rewatches,
  });

  /// Takes the entry [rateId] of [animeId] out of the list.
  Future<void> remove({required String animeId, required String rateId});
}
