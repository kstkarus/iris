import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/domain/user_rate_repository.dart';

/// The list entries changed or read since the screens showing them loaded,
/// by anime id; a null entry means the anime left the list.
///
/// Lists that loaded earlier (the catalog keeps its pages) show these over
/// what they were given, so a change on the anime page or in the player
/// shows everywhere at once.
class UserRateBookCubit extends Cubit<Map<String, UserRate?>> {
  UserRateBookCubit({required UserRateRepository repository})
    : super(const {}) {
    _subscription = repository.changes.listen((change) {
      if (isClosed) return;
      emit({...state, change.animeId: change.rate});
    });
  }

  late final StreamSubscription<UserRateChange> _subscription;

  /// Another account's list is another list.
  void clear() {
    if (state.isNotEmpty) emit(const {});
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}

extension UserRateBookContext on BuildContext {
  /// The entry for [animeId]: the latest one seen, otherwise [fallback]
  /// (what the screen's own data says). Rebuilds when the book changes.
  UserRate? watchUserRate(String animeId, UserRate? fallback) {
    final book = select<UserRateBookCubit?, ({bool known, UserRate? rate})>((
      cubit,
    ) {
      final state = cubit?.state;
      if (state == null || !state.containsKey(animeId)) {
        return (known: false, rate: null);
      }
      return (known: true, rate: state[animeId]);
    });
    return book.known ? book.rate : fallback;
  }
}
