import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/episode_metadata.dart';
import 'package:iris/features/player/domain/repositories/episode_metadata_repository.dart';
import 'package:iris/features/player/presentation/cubit/episode_metadata_cubit.dart';

class _RecordingRepository implements EpisodeMetadataRepository {
  final requests = <int?>[];

  @override
  Future<Map<int, EpisodeMetadata>> findForAnime({
    required String animeId,
    int? upToEpisode,
  }) async {
    requests.add(upToEpisode);
    return {
      1: const EpisodeMetadata(number: 1, title: 'First'),
      if ((upToEpisode ?? 1) > 100)
        120: const EpisodeMetadata(number: 120, title: 'Late', filler: true),
    };
  }
}

void main() {
  test(
    'loads initial page once and fetches further pages when needed',
    () async {
      final repository = _RecordingRepository();
      final cubit = EpisodeMetadataCubit(animeId: '20', repository: repository);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.keys, [1]);
      expect(repository.requests, [1]);

      // Already covered by initial load.
      await cubit.ensureLoadedUpTo(1);
      expect(repository.requests, [1]);

      // Extends beyond first request.
      await cubit.ensureLoadedUpTo(120);
      expect(cubit.state.keys, [1, 120]);
      expect(cubit.state[120]?.filler, isTrue);
      expect(repository.requests, [1, 120]);

      // Already requested up to 120.
      await cubit.ensureLoadedUpTo(110);
      expect(repository.requests, [1, 120]);
    },
  );
}
