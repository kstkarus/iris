import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/domain/user_rate_repository.dart';

sealed class EpisodeMarkResult {
  const EpisodeMarkResult();
}

/// The list already counts the episode; nothing was sent.
final class EpisodeAlreadyMarked extends EpisodeMarkResult {
  const EpisodeAlreadyMarked({this.current});

  final UserRate? current;
}

/// Durably saved on this device; Shikimori has not confirmed it yet.
final class EpisodeMarkDeferred extends EpisodeMarkResult {
  const EpisodeMarkDeferred();
}

/// A reset or a new viewing cycle superseded the offline mark.
final class EpisodeMarkObsolete extends EpisodeMarkResult {
  const EpisodeMarkObsolete(this.current);

  final UserRate? current;
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
abstract interface class EpisodeMarker {
  Future<EpisodeMarkResult> call({
    required String userId,
    required String animeId,
    required int episode,
    bool Function()? isCurrent,
  });

  Future<void> undo({
    required String userId,
    required String animeId,
    required EpisodeMarked mark,
    bool Function()? isCurrent,
  });
}

class MarkEpisodeWatched implements EpisodeMarker {
  const MarkEpisodeWatched(this._repository);

  final UserRateRepository _repository;

  @override
  Future<EpisodeMarkResult> call({
    required String userId,
    required String animeId,
    required int episode,
    bool Function()? isCurrent,
    bool baselineKnown = false,
    UserRate? baseline,
    Future<void> Function(UserRate? current)? beforeSave,
  }) async {
    if (episode < 1 || episode > 9999) {
      throw ArgumentError.value(episode, 'episode');
    }
    final (rate: current, :totalEpisodes) = await _repository.fetchWithTotal(
      animeId,
    );
    if (isCurrent != null && !isCurrent()) {
      throw StateError('Account session changed');
    }
    if (baselineKnown && _superseded(baseline, current)) {
      return EpisodeMarkObsolete(current);
    }
    if (current != null && current.episodes >= episode) {
      return EpisodeAlreadyMarked(current: current);
    }
    await beforeSave?.call(current);
    if (isCurrent != null && !isCurrent()) {
      throw StateError('Account session changed');
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
      status: status == current?.status ? null : status,
      episodes: episode,
    );
    return EpisodeMarked(previous: current, saved: saved);
  }

  /// Puts the list back as it was before [mark].
  @override
  Future<void> undo({
    required String userId,
    required String animeId,
    required EpisodeMarked mark,
    bool Function()? isCurrent,
  }) async {
    if (isCurrent != null && !isCurrent()) return;
    final current = await _repository.fetch(animeId);
    if (isCurrent != null && !isCurrent()) return;
    // Undo only our own change, keeping later edits and progress intact.
    if (current == null ||
        current.id != mark.saved.id ||
        current.episodes != mark.saved.episodes ||
        current.status != mark.saved.status ||
        current.rewatches != mark.saved.rewatches) {
      return;
    }
    final previous = mark.previous;
    if (previous == null) {
      if (current.score != mark.saved.score) return;
      await _repository.remove(animeId: animeId, rateId: mark.saved.id);
      return;
    }
    await _repository.save(
      userId: userId,
      animeId: animeId,
      rateId: mark.saved.id,
      status: previous.status,
      episodes: previous.episodes,
      rewatches: previous.rewatches,
    );
  }

  bool _superseded(UserRate? baseline, UserRate? current) {
    if (current?.status == UserRateStatus.rewatching &&
        baseline?.status != UserRateStatus.rewatching) {
      return true;
    }
    if (baseline == null) return false;
    if (current == null || current.id != baseline.id) return true;
    return current.episodes < baseline.episodes ||
        (current.rewatches != null &&
            baseline.rewatches != null &&
            current.rewatches != baseline.rewatches);
  }
}
