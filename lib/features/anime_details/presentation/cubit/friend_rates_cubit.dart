import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/entities/friend/domain/friends_repository.dart';

/// The signed-in user's friends who have the anime in their lists, in the
/// friends list's order. Empty until all are read, signed out, or when
/// the friends do not load: it is secondary, so it never says it failed.
class FriendRatesCubit extends Cubit<List<FriendRate>> {
  FriendRatesCubit({
    required String animeId,
    required FriendsRepository repository,
  }) : _animeId = animeId,
       _repository = repository,
       super(const []);

  /// Each friend is one request against Shikimori's 90 a minute.
  static const maxFriends = 30;

  final String _animeId;
  final FriendsRepository _repository;

  /// Bumped by every [show], so an older read stops.
  int _request = 0;

  Future<void> show(String? userId) async {
    final request = ++_request;
    if (state.isNotEmpty) emit(const []);
    if (userId == null || _animeId.isEmpty) return;
    final List<Friend> friends;
    try {
      friends = await _repository.friends(userId);
    } on Object {
      return;
    }
    final found = <FriendRate>[];
    // One at a time, so the rest of the app's requests queue between
    // these instead of behind all of them.
    for (final friend in friends.take(maxFriends)) {
      if (isClosed || request != _request) return;
      try {
        final rate = await _repository.rateOf(
          friendId: friend.id,
          animeId: _animeId,
        );
        if (rate != null) found.add(FriendRate(friend: friend, rate: rate));
      } on Object {
        // One friend's list not answering leaves the others.
      }
    }
    if (isClosed || request != _request) return;
    emit(found);
  }
}
