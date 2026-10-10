import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/domain/user_rate_repository.dart';

/// An in-memory list, for the mock app and tests.
class MockUserRateRepository implements UserRateRepository {
  final _rates = <String, UserRate>{};
  var _nextId = 1;

  @override
  Future<UserRate?> fetch(String animeId) async => _rates[animeId];

  @override
  Future<UserRate> save({
    required String userId,
    required String animeId,
    required String? rateId,
    required UserRateStatus status,
    required int episodes,
  }) async {
    final rate = UserRate(
      id: rateId ?? '${_nextId++}',
      status: status,
      episodes: episodes,
    );
    _rates[animeId] = rate;
    return rate;
  }

  @override
  Future<void> remove(String rateId) async =>
      _rates.removeWhere((_, rate) => rate.id == rateId);
}
