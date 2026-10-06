import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/repositories/player_skip_times_repository.dart';

/// Knows no skip times, so mock runs stay offline.
class MockPlayerSkipTimesRepository implements PlayerSkipTimesRepository {
  const MockPlayerSkipTimesRepository();

  @override
  Future<List<PlayerSkipSegment>> find({
    required String animeId,
    required int episode,
    required Duration duration,
  }) async {
    return const [];
  }
}
