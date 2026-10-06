import 'package:iris/features/player/domain/entities/player_skip_segment.dart';

/// Opening, ending and recap times published for an anime's episodes.
abstract interface class PlayerSkipTimesRepository {
  /// [animeId] is the Shikimori id, which is also the MyAnimeList id;
  /// [duration] tells apart releases with differently cut episodes. Empty
  /// when nothing is known or the lookup fails.
  Future<List<PlayerSkipSegment>> find({
    required String animeId,
    required int episode,
    required Duration duration,
  });
}
