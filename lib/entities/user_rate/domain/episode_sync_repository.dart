import 'package:iris/entities/user_rate/domain/user_rate.dart';

/// A frozen server snapshot and the episode counts still awaiting confirmation.
/// Entries without pending counts cache the last known snapshot for offline use.
class EpisodeSyncEntry {
  const EpisodeSyncEntry({
    required this.userId,
    required this.animeId,
    this.rateKnown = false,
    this.rate,
    this.episodes = const [],
    this.blocked = false,
  });

  final String userId;
  final String animeId;
  final bool rateKnown;
  final UserRate? rate;
  final List<int> episodes;
  final bool blocked;

  EpisodeSyncEntry withEpisodes(List<int> value, {bool blocked = false}) =>
      EpisodeSyncEntry(
        userId: userId,
        animeId: animeId,
        rateKnown: rateKnown,
        rate: rate,
        episodes: List.unmodifiable(value),
        blocked: blocked,
      );

  EpisodeSyncEntry observed(UserRate? value, {List<int>? remaining}) =>
      EpisodeSyncEntry(
        userId: userId,
        animeId: animeId,
        rateKnown: true,
        rate: value,
        episodes: List.unmodifiable(remaining ?? episodes),
      );
}

abstract interface class EpisodeSyncRepository {
  List<EpisodeSyncEntry> read();
  Future<void> write(List<EpisodeSyncEntry> entries);
}
