import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_state.dart';

class DownloadManagerCubit extends Cubit<DownloadManagerState> {
  DownloadManagerCubit({required DownloadsRepository repository})
    : _repository = repository,
      super(const DownloadManagerState());

  final DownloadsRepository _repository;
  StreamSubscription<List<DownloadItem>>? _subscription;

  Future<void> load() async {
    if (_subscription != null && !state.hasError) return;
    emit(state.copyWith(isLoading: true, hasError: false));
    final failed = _subscription;
    if (failed != null) {
      await failed.cancel();
      if (isClosed) return;
      _subscription = null;
    }
    try {
      _subscription = _repository.watchDownloads().listen(
        (downloads) {
          if (!isClosed) {
            emit(
              state.copyWith(
                isLoading: false,
                downloads: downloads,
                hasError: false,
              ),
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          _report(error, stackTrace);
        },
        onDone: () {
          _subscription = null;
        },
      );
      await refreshStorage();
    } catch (error, stackTrace) {
      _report(error, stackTrace);
    }
  }

  Future<void> pause(String id) => state.deletingIds.contains(id)
      ? Future.value()
      : _run(() => _repository.pause(id: id));

  Future<void> resume(String id) => state.deletingIds.contains(id)
      ? Future.value()
      : _run(() => _repository.resume(id: id));

  Future<void> retry(String id) => state.deletingIds.contains(id)
      ? Future.value()
      : _run(() => _repository.retry(id: id));

  Future<void> downloadNext(String id) => state.deletingIds.contains(id)
      ? Future.value()
      : _run(() => _repository.downloadNext(id: id));

  Future<bool> reorderQueue(List<String> ids) async {
    if (isClosed) return false;
    try {
      await _repository.reorderQueue(ids: List.of(ids));
      return !isClosed;
    } catch (error, stackTrace) {
      _report(error, stackTrace);
      return false;
    }
  }

  /// Returns false when the files could not be removed.
  Future<bool> delete(String id) async => (await deleteMany([id])).isEmpty;

  Future<Set<String>> deleteMany(Iterable<String> ids) async {
    final pending = ids.toSet();
    if (pending.isEmpty || isClosed) return pending;
    final busy = pending.intersection(state.deletingIds);
    pending.removeAll(busy);
    if (pending.isEmpty) return busy;
    emit(
      state.copyWith(
        deletingIds: Set.unmodifiable({...state.deletingIds, ...pending}),
      ),
    );
    var failed = pending;
    try {
      failed = await _repository.deleteMany(ids: pending);
    } catch (error, stackTrace) {
      _report(error, stackTrace);
    } finally {
      await refreshStorage();
      if (!isClosed) {
        emit(
          state.copyWith(
            deletingIds: Set.unmodifiable(
              state.deletingIds.difference(pending),
            ),
          ),
        );
      }
    }
    return {...busy, ...failed};
  }

  /// Returns false when the cache is in use by an active stream.
  Future<bool> clearCache() async {
    try {
      final cleared = await _repository.clearCache();
      await refreshStorage();
      return cleared;
    } catch (error, stackTrace) {
      developer.log(
        'Unable to clear the cache.',
        name: 'iris.downloads.manager',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> refreshStorage() async {
    try {
      final usage = await _repository.calculateStorageUsage();
      if (!isClosed) emit(state.copyWith(storageUsage: usage));
    } catch (error, stackTrace) {
      developer.log(
        'Unable to calculate download storage usage.',
        name: 'iris.downloads.manager',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error, stackTrace) {
      _report(error, stackTrace);
    }
  }

  void _report(Object error, StackTrace stackTrace) {
    developer.log(
      'Download manager operation failed.',
      name: 'iris.downloads.manager',
      error: error,
      stackTrace: stackTrace,
    );
    if (!isClosed) emit(state.copyWith(isLoading: false, hasError: true));
  }

  @override
  Future<void> close() async {
    final subscription = _subscription;
    // Closing first keeps a load() waiting on a cancel from subscribing.
    await super.close();
    await subscription?.cancel();
  }
}
