import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/profile/domain/repositories/user_list_repository.dart';
import 'package:iris/features/profile/presentation/cubit/user_list_state.dart';

/// A user's list, one status at a time, read a page at a time as it is
/// scrolled.
///
/// Given the signed-in user's [changes], it quietly reads the status
/// again when an anime moves into it from elsewhere (the anime page, the
/// player), so the tab is current when it is next looked at. Entries
/// already shown are kept current by the rate book instead.
class UserListCubit extends Cubit<UserListState> {
  UserListCubit({
    required UserListRepository repository,
    Stream<UserRateChange>? changes,
  }) : _repository = repository,
       super(const UserListState()) {
    _subscription = changes?.listen(_onChange);
  }

  final UserListRepository _repository;
  StreamSubscription<UserRateChange>? _subscription;

  /// Bumped by every new start, so the answers of an older one are dropped.
  int _request = 0;

  /// Pages the next read steps back: a listed anime left this status
  /// elsewhere, so the server's pages moved up under the loaded ones and
  /// the next one would skip an entry. One departure reads the last page
  /// again; a departure while a page is in flight reads one page more too.
  int _stepBack = 0;

  /// A repeated change for one departure must not make the next read walk
  /// back again. The set is cleared when the first page is replaced.
  final Set<String> _departed = {};

  /// The first page is read again quietly; a further page now would be
  /// added to what that read replaces.
  bool _rereading = false;

  /// Shows [userId]'s list, or nobody's.
  void show(String? userId) {
    if (userId == state.userId && state.load != UserListLoad.failed) return;
    _start(userId: userId, status: state.status);
  }

  void select(UserRateStatus status) {
    if (status == state.status) return;
    _start(userId: state.userId, status: status);
  }

  /// Tries the failed read again.
  void retry() {
    if (state.load == UserListLoad.failed) {
      _start(userId: state.userId, status: state.status);
    } else if (state.moreFailed) {
      loadMore();
    }
  }

  Future<void> loadMore() async {
    final userId = state.userId;
    if (userId == null ||
        state.load != UserListLoad.loaded ||
        !state.hasMore ||
        state.loadingMore ||
        _rereading) {
      return;
    }
    final request = _request;
    // After a shift the pages read last hold what moved up into them.
    final back = _stepBack;
    _stepBack = 0;
    final number = math.max(1, state.page + 1 - back);
    emit(state.copyWith(loadingMore: true, moreFailed: false));
    try {
      final page = await _repository.page(
        userId: userId,
        status: state.status,
        page: number,
      );
      if (isClosed || request != _request) return;
      emit(
        state.copyWith(
          entries: [
            ...state.entries,
            ...page.entries.where((entry) => !_lists(entry.anime.id)),
          ],
          page: number,
          hasMore: page.hasMore || _stepBack > 0,
          loadingMore: false,
        ),
      );
    } on Object {
      if (isClosed || request != _request) return;
      _stepBack += back;
      emit(state.copyWith(loadingMore: false, moreFailed: true));
    }
  }

  void _start({required String? userId, required UserRateStatus status}) {
    _request++;
    _stepBack = 0;
    _departed.clear();
    _rereading = false;
    if (userId == null) {
      emit(UserListState(status: status, load: UserListLoad.loaded));
      return;
    }
    emit(UserListState(userId: userId, status: status));
    unawaited(_readFirstPage(quietly: false));
  }

  Future<void> _readFirstPage({required bool quietly}) async {
    final userId = state.userId;
    if (userId == null) return;
    final request = _request;
    final status = state.status;
    _rereading = quietly;
    try {
      final page = await _repository.page(
        userId: userId,
        status: status,
        page: 1,
      );
      if (isClosed || request != _request) return;
      final stepBack = _stepBack;
      _departed.clear();
      emit(
        UserListState(
          userId: userId,
          status: status,
          entries: page.entries,
          load: UserListLoad.loaded,
          page: 1,
          hasMore: page.hasMore || stepBack > 0,
        ),
      );
    } on Object {
      if (isClosed || request != _request || quietly) return;
      emit(state.copyWith(load: UserListLoad.failed));
    } finally {
      if (request == _request) _rereading = false;
    }
  }

  void _onChange(UserRateChange change) {
    final rate = change.rate;
    if (!isClosed && _lists(change.animeId)) {
      if (rate?.status == state.status) {
        _departed.remove(change.animeId);
      } else if (_departed.add(change.animeId)) {
        _stepBack += state.loadingMore ? 2 : 1;
        if (!state.hasMore) emit(state.copyWith(hasMore: true));
      }
      if (rate == null || rate.status != state.status) {
        return;
      }
    }
    if (isClosed ||
        state.load != UserListLoad.loaded ||
        state.loadingMore ||
        rate == null ||
        rate.status != state.status ||
        _lists(change.animeId)) {
      return;
    }
    _request++;
    unawaited(_readFirstPage(quietly: true));
  }

  bool _lists(String animeId) =>
      state.entries.any((entry) => entry.anime.id == animeId);

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
