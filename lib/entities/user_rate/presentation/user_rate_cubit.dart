import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/domain/user_rate_repository.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_state.dart';

/// One anime's entry in the signed-in user's Shikimori list.
///
/// Changes show at once and are sent one after another, the latest wish
/// last, so quick taps on the episode count neither race nor add the
/// anime twice. A change Shikimori does not take falls back to what it
/// keeps. What changes the entry elsewhere (the player marking an
/// episode) shows here too, so the next change starts from it.
class UserRateCubit extends Cubit<UserRateState> {
  UserRateCubit({
    required UserRateRepository repository,
    required String animeId,
  }) : _repository = repository,
       _animeId = animeId,
       super(const UserRateSignedOut()) {
    _changes = repository.changes.listen(_onChange);
  }

  final UserRateRepository _repository;
  final String _animeId;
  late final StreamSubscription<UserRateChange> _changes;

  String? _userId;

  /// The entry as Shikimori last confirmed it.
  UserRate? _saved;

  /// What to send next, while a save is out.
  ({UserRateStatus status, int episodes, int score})? _wish;
  bool _sending = false;
  bool _removing = false;

  /// Bumped by every account change: a save or removal still out for the
  /// account before settles nothing for this one.
  int _session = 0;

  /// Follows the session: [userId] is the signed-in account, or null.
  Future<void> accountChanged(String? userId) async {
    if (userId == _userId) return;
    _userId = userId;
    _session++;
    _saved = null;
    _wish = null;
    _sending = false;
    _removing = false;
    if (userId == null) {
      emit(const UserRateSignedOut());
      return;
    }
    await load();
  }

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) return;
    emit(const UserRateLoading());
    try {
      final rate = await _repository.fetch(_animeId);
      if (isClosed || userId != _userId) return;
      _saved = rate;
      emit(UserRateLoaded(rate));
    } on Exception {
      if (!isClosed && userId == _userId) emit(const UserRateLoadFailure());
    }
  }

  void setStatus(UserRateStatus status) {
    final current = _current;
    if (current == null) return;
    _request(
      status: status,
      episodes: current.rate?.episodes ?? 0,
      score: current.rate?.score ?? 0,
    );
  }

  /// 1 to 10, or 0 to clear; scoring an anime not in the list adds it as
  /// completed, as one rates what one has seen.
  void setScore(int score) {
    final current = _current;
    if (current == null || score < 0 || score > UserRate.maxScore) return;
    final rate = current.rate;
    _request(
      status: rate?.status ?? UserRateStatus.completed,
      episodes: rate?.episodes ?? 0,
      score: score,
    );
  }

  /// One episode more or less, within [total] when it is known; marking
  /// an episode of an anime not in the list adds it as watching.
  void stepEpisodes(int delta, {int? total}) {
    final current = _current;
    if (current == null) return;
    final rate = current.rate;
    var episodes = (rate?.episodes ?? 0) + delta;
    if (episodes < 0) return;
    if (total != null && total > 0 && episodes > total) return;
    _request(
      status: rate?.status ?? UserRateStatus.watching,
      episodes: episodes,
      score: rate?.score ?? 0,
    );
  }

  Future<void> remove() async {
    final current = _current;
    final saved = _saved;
    if (current == null || current.saving || saved == null) return;
    final session = _session;
    emit(const UserRateLoaded(null, saving: true));
    _removing = true;
    try {
      await _repository.remove(animeId: _animeId, rateId: saved.id);
      if (session != _session) return;
      _saved = null;
      if (!isClosed) emit(const UserRateLoaded(null));
    } on Exception {
      if (!isClosed && session == _session) {
        emit(UserRateLoaded(saved, saveFailed: true));
        _resync();
      }
    } finally {
      if (session == _session) _removing = false;
    }
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }

  /// Takes the entry as another screen saved or read it; this cubit's own
  /// saves and removals settle by themselves.
  void _onChange(UserRateChange change) {
    if (isClosed || change.animeId != _animeId || _userId == null) return;
    if (_sending || _removing) return;
    // The same entry read again keeps a failure shown with it.
    if (change.rate == _saved && _current?.rate == change.rate) return;
    _saved = change.rate;
    emit(UserRateLoaded(change.rate));
  }

  /// Reads the entry again after a change that failed: one that timed out
  /// may still have reached Shikimori, and the next change must start from
  /// what it keeps. The read comes back through [_onChange].
  void _resync() {
    unawaited(
      _repository.fetch(_animeId).then<void>((_) {}, onError: (Object _) {}),
    );
  }

  UserRateLoaded? get _current => switch (state) {
    final UserRateLoaded loaded => loaded,
    _ => null,
  };

  void _request({
    required UserRateStatus status,
    required int episodes,
    required int score,
  }) {
    // The entry is on its way out; a change now would go to a rate that
    // is gone, or bring it back unseen.
    if (_removing) return;
    _wish = (status: status, episodes: episodes, score: score);
    emit(
      UserRateLoaded(
        UserRate(
          id: _saved?.id ?? '',
          status: status,
          episodes: episodes,
          score: score,
        ),
        saving: true,
      ),
    );
    if (!_sending) _send();
  }

  Future<void> _send() async {
    final userId = _userId;
    if (userId == null) return;
    final session = _session;
    _sending = true;
    try {
      while (_wish != null) {
        final wish = _wish!;
        _wish = null;
        final saved = await _repository.save(
          userId: userId,
          animeId: _animeId,
          rateId: _saved?.id,
          status: wish.status,
          episodes: wish.episodes,
          score: wish.score,
        );
        if (isClosed || session != _session) return;
        _saved = saved;
      }
      emit(UserRateLoaded(_saved));
    } on Exception {
      if (isClosed || session != _session) return;
      _wish = null;
      emit(UserRateLoaded(_saved, saveFailed: true));
      _resync();
    } finally {
      if (session == _session) _sending = false;
    }
  }
}
