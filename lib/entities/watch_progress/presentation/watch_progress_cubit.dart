import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress_repository.dart';

/// App-wide watch history, most recently updated first.
class WatchProgressCubit extends Cubit<List<WatchProgress>> {
  WatchProgressCubit({required WatchProgressRepository repository})
    : _repository = repository,
      super(const []);

  final WatchProgressRepository _repository;
  StreamSubscription<List<WatchProgress>>? _subscription;

  void load() {
    _subscription ??= _repository.watchAll().listen(
      (items) {
        if (!isClosed) emit(items);
      },
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'Unable to read watch history.',
          name: 'iris.watch_progress.cubit',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  Future<void> removeTorrent(String torrentKey) {
    return _repository.removeTorrent(torrentKey: torrentKey);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

extension WatchProgressContext on BuildContext {
  /// The watch history, or an empty list where no [WatchProgressCubit] is
  /// provided (isolated widget tests).
  List<WatchProgress> watchWatchProgress() {
    return watch<WatchProgressCubit?>()?.state ?? const [];
  }
}
