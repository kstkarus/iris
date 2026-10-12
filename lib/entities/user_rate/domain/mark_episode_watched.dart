import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/domain/user_rate_repository.dart';

sealed class EpisodeMarkResult {
  const EpisodeMarkResult();
}

/// The list already counts the episode; nothing was sent.
final class EpisodeAlreadyMarked extends EpisodeMarkResult {
  const EpisodeAlreadyMarked();
}

final class EpisodeMarked extends EpisodeMarkResult {
  const EpisodeMarked({required this.previous, required this.saved});

  /// The entry before, to put back on undo; null when the anime was not in
  /// the list.
  final UserRate? previous;
  final UserRate saved;
}

/// Counts an episode as watched in the user's Shikimori list.
///
/// The count only grows: an episode at or below it changes nothing. An
/// anime planned, put on hold, dropped or not in the list becomes
/// watching, or completed with its last episode; a rewatch or a finished
/// anime keeps its status.
///
/// Shikimori finishes an anime by itself when the count reaches the last
/// episode, but only when the same change leaves the status alone, so the
/// last episode of an anime that was not being watched (a film added to
/// the list from its page) is completed here.
class MarkEpisodeWatched {
  const MarkEpisodeWatched(this._repository);

  final UserRateRepository _repository;

  Future<EpisodeMarkResult> call({
    required String userId,
    required String animeId,
    required int episode,
  }) async {
    final (rate: current, :totalEpisodes) = await _repository.fetchWithTotal(
      animeId,
    );
    if (current != null && current.episodes >= episode) {
      return const EpisodeAlreadyMarked();
    }
    final last = totalEpisodes > 0 && episode >= totalEpisodes;
    final status = switch (current?.status) {
      // Shikimori ends a rewatch itself and counts it.
      UserRateStatus.rewatching => UserRateStatus.rewatching,
      UserRateStatus.completed => UserRateStatus.completed,
      _ when last => UserRateStatus.completed,
      _ => UserRateStatus.watching,
    };
    final saved = await _repository.save(
      userId: userId,
      animeId: animeId,
      rateId: current?.id,
      status: status,
      episodes: episode,
      score: current?.score ?? 0,
    );
    return EpisodeMarked(previous: current, saved: saved);
  }

  /// Puts the list back as it was before [mark].
  Future<void> undo({
    required String userId,
    required String animeId,
    required EpisodeMarked mark,
  }) async {
    final previous = mark.previous;
    if (previous == null) {
      await _repository.remove(animeId: animeId, rateId: mark.saved.id);
      return;
    }
    await _repository.save(
      userId: userId,
      animeId: animeId,
      rateId: mark.saved.id,
      status: previous.status,
      episodes: previous.episodes,
      score: previous.score,
    );
  }
}
