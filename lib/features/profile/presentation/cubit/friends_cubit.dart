import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/entities/friend/domain/friends_repository.dart';

sealed class FriendsState {
  const FriendsState();
}

class FriendsLoading extends FriendsState {
  const FriendsLoading();
}

class FriendsLoaded extends FriendsState {
  const FriendsLoaded(this.friends);

  final List<Friend> friends;
}

class FriendsFailed extends FriendsState {
  const FriendsFailed();
}

/// The signed-in user's Shikimori friends, read when first asked for.
class FriendsCubit extends Cubit<FriendsState> {
  FriendsCubit({required FriendsRepository repository})
    : _repository = repository,
      super(const FriendsLoading());

  final FriendsRepository _repository;
  String? _userId;
  bool _asked = false;

  /// Bumped by every read, so the answer of an older one is dropped.
  int _request = 0;

  /// Whose friends; read only once [load] has been asked for.
  void show(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _request++;
    emit(const FriendsLoading());
    if (_asked) load();
  }

  /// Reads the friends, unless they are read. A call while they are being
  /// read asks again and drops the earlier answer; the repository keeps the
  /// request, so no second one goes out.
  Future<void> load() async {
    _asked = true;
    final userId = _userId;
    if (userId == null) {
      emit(const FriendsLoaded([]));
      return;
    }
    if (state is FriendsLoaded) return;
    final request = ++_request;
    emit(const FriendsLoading());
    try {
      final friends = await _repository.friends(userId);
      if (isClosed || request != _request) return;
      emit(FriendsLoaded(friends));
    } on Object {
      if (isClosed || request != _request) return;
      emit(const FriendsFailed());
    }
  }
}
