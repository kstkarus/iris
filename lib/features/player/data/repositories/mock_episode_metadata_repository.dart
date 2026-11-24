import 'package:iris/features/player/domain/entities/episode_metadata.dart';
import 'package:iris/features/player/domain/repositories/episode_metadata_repository.dart';

/// Knows no episode metadata, so mock runs stay offline.
class MockEpisodeMetadataRepository implements EpisodeMetadataRepository {
  const MockEpisodeMetadataRepository();

  @override
  Future<Map<int, EpisodeMetadata>> findForAnime({
    required String animeId,
    int? upToEpisode,
  }) async {
    return const {};
  }
}
