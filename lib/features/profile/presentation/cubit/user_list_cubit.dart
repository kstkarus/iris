import 'dart:async';

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

  /// A listed anime left this status elsewhere: the server's pages moved
  /// up under the loaded ones, and the next one would skip an entry.
  bool _shifted = false;

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
        state.loadingMore) {
      return;
    }
    final request = _request;
    // After a shift the last page read holds what moved up into it.
    final shifted = _shifted;
    _shifted = false;
    final number = shifted ? state.page : state.page + 1;
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
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
    } on Object {
      if (isClosed || request != _request) return;
      _shifted = _shifted || shifted;
      emit(state.copyWith(loadingMore: false, moreFailed: true));
    }
  }

  void _start({required String? userId, required UserRateStatus status}) {
    _request++;
    _shifted = false;
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
    try {
      final page = await _repository.page(
        userId: userId,
        status: status,
        page: 1,
      );
      if (isClosed || request != _request) return;
      _shifted = false;
      emit(
        UserListState(
          userId: userId,
          status: status,
          entries: page.entries,
          load: UserListLoad.loaded,
          page: 1,
          hasMore: page.hasMore,
        ),
      );
    } on Object {
      if (isClosed || request != _request || quietly) return;
      emit(state.copyWith(load: UserListLoad.failed));
    }
  }

  void _onChange(UserRateChange change) {
    final rate = change.rate;
    if (!isClosed &&
        _lists(change.animeId) &&
        (rate == null || rate.status != state.status)) {
      _shifted = true;
      return;
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
