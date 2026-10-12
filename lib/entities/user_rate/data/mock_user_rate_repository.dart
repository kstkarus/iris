import 'dart:async';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/domain/user_rate_repository.dart';

/// An in-memory list, for the mock app and tests.
class MockUserRateRepository implements UserRateRepository {
  final _rates = <String, UserRate>{};

  /// Episode counts by anime id; an anime left out has none known.
  final totalEpisodes = <String, int>{};
  final _changes = StreamController<UserRateChange>.broadcast();
  var _nextId = 1;

  /// Every entry, by anime id.
  Map<String, UserRate> get rates => Map.unmodifiable(_rates);

  @override
  Stream<UserRateChange> get changes => _changes.stream;

  @override
  Future<UserRate?> fetch(String animeId) async {
    final rate = _rates[animeId];
    _changes.add(UserRateChange(animeId, rate));
    return rate;
  }

  @override
  Future<({UserRate? rate, int totalEpisodes})> fetchWithTotal(
    String animeId,
  ) async =>
      (rate: await fetch(animeId), totalEpisodes: totalEpisodes[animeId] ?? 0);

  @override
  Future<UserRate> save({
    required String userId,
    required String animeId,
    required String? rateId,
    required UserRateStatus status,
    required int episodes,
    required int score,
  }) async {
    final rate = UserRate(
      id: rateId ?? '${_nextId++}',
      status: status,
      episodes: episodes,
      score: score,
    );
    _rates[animeId] = rate;
    _changes.add(UserRateChange(animeId, rate));
    return rate;
  }

  @override
  Future<void> remove({required String animeId, required String rateId}) async {
    _rates.remove(animeId);
    _changes.add(UserRateChange(animeId, null));
  }
}
