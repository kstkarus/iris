import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';

/// Tracks whether any download is currently transferring or queued.
///
/// Emits only when activity flips between active and idle so navigation chrome
/// never rebuilds on byte-progress ticks.
class DownloadActivityCubit extends Cubit<bool> {
  DownloadActivityCubit({DownloadsRepository? repository}) : super(false) {
    if (repository != null) {
      _subscription = repository.watchDownloads().listen(
        sync,
        onError: (Object error, StackTrace stackTrace) {
          developer.log(
            'Unable to watch download activity.',
            name: 'iris.downloads.activity',
            error: error,
            stackTrace: stackTrace,
          );
          clear();
        },
      );
    }
  }

  StreamSubscription<List<DownloadItem>>? _subscription;

  void sync(List<DownloadItem> items) {
    if (!isClosed) emit(_hasActiveDownloads(items));
  }

  void clear() {
    if (!isClosed) emit(false);
  }

  static bool _hasActiveDownloads(List<DownloadItem> items) => items.any(
    (item) =>
        item.status == DownloadStatus.downloading ||
        item.status == DownloadStatus.queued,
  );

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
