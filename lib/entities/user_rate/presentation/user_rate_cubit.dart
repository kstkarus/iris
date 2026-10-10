import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/domain/user_rate_repository.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_state.dart';

/// One anime's entry in the signed-in user's Shikimori list.
///
/// Changes show at once and are sent one after another, the latest wish
/// last, so quick taps on the episode count neither race nor add the
/// anime twice. A change Shikimori does not take falls back to what it
/// keeps.
class UserRateCubit extends Cubit<UserRateState> {
  UserRateCubit({
    required UserRateRepository repository,
    required String animeId,
  }) : _repository = repository,
       _animeId = animeId,
       super(const UserRateSignedOut());

  final UserRateRepository _repository;
  final String _animeId;

  String? _userId;

  /// The entry as Shikimori last confirmed it.
  UserRate? _saved;

  /// What to send next, while a save is out.
  ({UserRateStatus status, int episodes})? _wish;
  bool _sending = false;

  /// Follows the session: [userId] is the signed-in account, or null.
  Future<void> accountChanged(String? userId) async {
    if (userId == _userId) return;
    _userId = userId;
    _saved = null;
    _wish = null;
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
    _request(status: status, episodes: current.rate?.episodes ?? 0);
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
    );
  }

  Future<void> remove() async {
    final current = _current;
    final saved = _saved;
    if (current == null || current.saving || saved == null) return;
    emit(const UserRateLoaded(null, saving: true));
    try {
      await _repository.remove(saved.id);
      _saved = null;
      if (!isClosed) emit(const UserRateLoaded(null));
    } on Exception {
      if (!isClosed) emit(UserRateLoaded(saved, saveFailed: true));
    }
  }

  UserRateLoaded? get _current => switch (state) {
    final UserRateLoaded loaded => loaded,
    _ => null,
  };

  void _request({required UserRateStatus status, required int episodes}) {
    _wish = (status: status, episodes: episodes);
    emit(
      UserRateLoaded(
        UserRate(id: _saved?.id ?? '', status: status, episodes: episodes),
        saving: true,
      ),
    );
    if (!_sending) _send();
  }

  Future<void> _send() async {
    final userId = _userId;
    if (userId == null) return;
    _sending = true;
    try {
      while (_wish != null) {
        final wish = _wish!;
        _wish = null;
        _saved = await _repository.save(
          userId: userId,
          animeId: _animeId,
          rateId: _saved?.id,
          status: wish.status,
          episodes: wish.episodes,
        );
        if (isClosed || userId != _userId) return;
      }
      emit(UserRateLoaded(_saved));
    } on Exception {
      _wish = null;
      if (!isClosed && userId == _userId) {
        emit(UserRateLoaded(_saved, saveFailed: true));
      }
    } finally {
      _sending = false;
    }
  }
}
