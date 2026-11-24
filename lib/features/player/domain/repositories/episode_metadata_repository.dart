import 'package:iris/features/player/domain/entities/episode_metadata.dart';

/// Optional episode metadata (titles, filler and recap flags) keyed by the
/// anime's whole episode number.
abstract interface class EpisodeMetadataRepository {
  /// Returns known episodes for [animeId], loading pages up to [upToEpisode]
  /// (or the first page when omitted). Optional: fails quietly with whatever
  /// episodes could be loaded.
  Future<Map<int, EpisodeMetadata>> findForAnime({
    required String animeId,
    int? upToEpisode,
  });
}
