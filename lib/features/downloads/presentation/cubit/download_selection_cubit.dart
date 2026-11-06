import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_state.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';
import 'package:iris/features/online_sources/domain/online_stream_choice.dart';
import 'package:iris/features/online_sources/domain/repositories/online_quality_preferences.dart';
import 'package:iris/shared/utils/equality.dart';

/// Keeps the source open while individual files or a selected batch are queued.
class DownloadSelectionCubit extends Cubit<DownloadSelectionState> {
  DownloadSelectionCubit({
    required this.args,
    required DownloadsRepository repository,
    OnlineQualityPreferences? qualityPreferences,
  }) : _repository = repository,
       _qualityPreferences = qualityPreferences,
       super(const DownloadSelectionInitial()) {
    _watchDownloads();
  }

  final DownloadSelectionArgs args;
  final DownloadsRepository _repository;

  /// Remembers the quality last chosen for downloading online episodes.
  final OnlineQualityPreferences? _qualityPreferences;
  PreparedDownloadSource? _source;
  int _attempt = 0;
  Completer<void>? _preparationCancel;
  StreamSubscription<Map<int, DownloadItem>>? _downloadsSubscription;
  Map<int, DownloadItem> _downloads = const {};
  bool _downloadsFailed = false;
  Future<void>? _batch;

  Future<void> load() async {
    final attempt = ++_attempt;
    _cancelPreparation();
    // Let go first: a new preparation of the same torrent would borrow the
    // old one's, and lose it when the old one went.
    final previous = _source;
    _source = null;
    if (previous != null) {
      await _repository.disposePreparedSource(
        sourceToken: previous.sourceToken,
      );
      if (!_isCurrent(attempt)) return;
    }
    final preparationCancel = Completer<void>();
    _preparationCancel = preparationCancel;
    emit(const DownloadSelectionLoading());
    try {
      final source = await _repository.prepareSource(
        magnet: args.magnet,
        cancelled: preparationCancel.future,
      );
      if (!_isCurrent(attempt)) {
        await _repository.disposePreparedSource(
          sourceToken: source.sourceToken,
        );
        return;
      }
      _source = source;
      if (_downloadsFailed) {
        _downloadsFailed = false;
        _watchDownloads();
      }
      emit(
        DownloadSelectionReady(
          source,
          quality: _startingQuality(source),
          downloads: _downloads,
        ),
      );
    } on FormatException {
      if (_isCurrent(attempt)) {
        emit(
          const DownloadSelectionFailure(
            DownloadSelectionFailureType.unsupported,
          ),
        );
      }
    } catch (error, stackTrace) {
      // A superseded or closed attempt was cancelled on purpose; not a failure.
      if (!_isCurrent(attempt)) return;
      developer.log(
        'Unable to prepare torrent files for download.',
        name: 'iris.downloads.selection',
        error: error,
        stackTrace: stackTrace,
      );
      emit(
        const DownloadSelectionFailure(
          DownloadSelectionFailureType.unableToPrepare,
        ),
      );
    }
  }

  /// The quality last chosen for downloads, or the closest this release
  /// has; "Auto" for a torrent, which has no choice.
  int? _startingQuality(PreparedDownloadSource source) {
    final wanted = _qualityPreferences?.downloading;
    if (wanted == null || source.qualities.isEmpty) return null;
    return closestQuality(source.qualities, wanted);
  }

  /// Loads the episodes in [quality] (null: the best), and remembers it for
  /// the next downloads.
  void chooseQuality(int? quality) {
    final current = state;
    if (current is! DownloadSelectionReady || current.addingBatch) return;
    emit(current.copyWith(quality: () => quality));
    unawaited(_qualityPreferences?.setDownloading(quality));
  }

  void startSelection({int? index}) {
    final current = state;
    if (current is! DownloadSelectionReady || !current.canStartSelection) {
      return;
    }
    if (index != null &&
        (!current.source.files.any((file) => file.index == index) ||
            !current.canSelect(index))) {
      return;
    }
    emit(
      current.copyWith(
        selecting: true,
        selected: index == null ? null : {index},
      ),
    );
  }

  void cancelSelection() {
    final current = state;
    if (current is! DownloadSelectionReady || current.addingBatch) return;
    emit(current.copyWith(selecting: false, selected: const {}));
  }

  void toggleSelection(int index) {
    final current = state;
    if (current is! DownloadSelectionReady ||
        !current.selecting ||
        current.addingBatch ||
        !current.source.files.any((file) => file.index == index) ||
        !current.canSelect(index)) {
      return;
    }
    final selected = {...current.selected};
    if (!selected.remove(index)) selected.add(index);
    emit(current.copyWith(selected: selected));
  }

  void selectAll() {
    final current = state;
    if (current is! DownloadSelectionReady ||
        !current.selecting ||
        current.addingBatch) {
      return;
    }
    final available = {
      for (final file in current.source.files)
        if (current.canSelect(file.index)) file.index,
    };
    emit(
      current.copyWith(
        selected: sameSet(current.selected, available) ? const {} : available,
      ),
    );
  }

  /// Queues [file], or takes up its paused or failed download; one already
  /// queued, loading or done is left as it is.
  Future<void> download(DownloadableFile file) async {
    final current = state;
    if (current is DownloadSelectionReady && current.addingBatch) {
      return;
    }
    await _download(file);
  }

  Future<bool> _download(DownloadableFile file) async {
    final source = _source;
    final current = state;
    if (source == null || current is! DownloadSelectionReady) return false;
    final index = file.index;
    if (current.adding.contains(index)) return false;
    final existing = current.downloads[index];
    switch (existing?.status) {
      case DownloadStatus.paused:
        return _quietly(() => _repository.resume(id: existing!.id));
      case DownloadStatus.failed:
        return _quietly(() => _repository.retry(id: existing!.id));
      case DownloadStatus.queued ||
          DownloadStatus.downloading ||
          DownloadStatus.completed:
        return true;
      case null:
    }
    final quality = current.quality;
    emit(
      current.copyWith(
        adding: {...current.adding, index},
        notAdded: {...current.notAdded}..remove(index),
      ),
    );
    var added = false;
    try {
      final item = await _repository.enqueueDownload(
        source: source,
        file: file,
        animeId: args.animeId,
        animeTitle: args.animeTitle,
        sourceTitle: args.sourceTitle,
        posterUrl: args.posterUrl,
        quality: quality,
      );
      // The list of downloads may come a moment later; the row should not
      // go back to its download button meanwhile.
      _downloads = {..._downloads, index: _downloads[index] ?? item};
      added = true;
    } catch (error, stackTrace) {
      developer.log(
        'Unable to enqueue selected file.',
        name: 'iris.downloads.selection',
        error: error,
        stackTrace: stackTrace,
      );
    }
    final latest = state;
    if (isClosed || latest is! DownloadSelectionReady) return added;
    emit(
      latest.copyWith(
        downloads: _downloads,
        adding: {...latest.adding}..remove(index),
        notAdded: added ? null : {...latest.notAdded, index},
      ),
    );
    return added;
  }

  Future<void> downloadSelected() {
    final current = state;
    if (current is! DownloadSelectionReady ||
        !current.selecting ||
        current.selected.isEmpty) {
      return Future.value();
    }
    return _batch ??= _downloadFiles(
      selected: current.selected,
    ).whenComplete(() => _batch = null);
  }

  Future<void> _downloadFiles({required Set<int> selected}) async {
    final current = state;
    if (current is! DownloadSelectionReady ||
        current.addingBatch ||
        current.adding.isNotEmpty) {
      return;
    }
    emit(current.copyWith(addingBatch: true));
    final failed = <int>{};
    try {
      for (final file in current.source.files) {
        if (!selected.contains(file.index)) continue;
        if (isClosed || !identical(_source, current.source)) return;
        if (!await _download(file)) failed.add(file.index);
      }
    } finally {
      final latest = state;
      if (!isClosed && latest is DownloadSelectionReady) {
        emit(
          latest.copyWith(
            addingBatch: false,
            selecting: failed.isNotEmpty,
            selected: failed,
          ),
        );
      }
    }
  }

  Future<bool> _quietly(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (error, stackTrace) {
      developer.log(
        'Unable to take up a download again.',
        name: 'iris.downloads.selection',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Follows the source's downloads. A list that fails to load (the
  /// downloads not restored yet) is followed again with the next
  /// preparation, which restores them first.
  void _watchDownloads() {
    _downloadsSubscription?.cancel().ignore();
    _downloadsSubscription = _repository
        .watchSourceDownloads(magnet: args.magnet)
        .listen(
          _onDownloads,
          onError: (Object error, StackTrace stackTrace) {
            developer.log(
              'Unable to follow the downloads of the source.',
              name: 'iris.downloads.selection',
              error: error,
              stackTrace: stackTrace,
            );
            _downloadsFailed = true;
          },
        );
  }

  void _onDownloads(Map<int, DownloadItem> downloads) {
    _downloads = downloads;
    final current = state;
    if (isClosed || current is! DownloadSelectionReady) return;
    final updated = current.copyWith(downloads: downloads);
    emit(
      updated.copyWith(
        selected: current.addingBatch
            ? null
            : current.selected.where(updated.canSelect).toSet(),
      ),
    );
  }

  @override
  Future<void> close() async {
    _attempt++;
    _cancelPreparation();
    // Leaving the picker does not cancel the season the user just queued.
    // Keep its prepared source until every requested file has been added.
    await _batch;
    try {
      await _downloadsSubscription?.cancel();
    } catch (_) {
      // Its failure was logged when it came.
    }
    final source = _source;
    _source = null;
    if (source != null) {
      try {
        await _repository.disposePreparedSource(
          sourceToken: source.sourceToken,
        );
      } catch (error, stackTrace) {
        developer.log(
          'Unable to let the prepared source go.',
          name: 'iris.downloads.selection',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return super.close();
  }

  bool _isCurrent(int attempt) => !isClosed && attempt == _attempt;

  /// Tells a running preparation that nobody waits for its result any more.
  void _cancelPreparation() {
    _preparationCancel?.complete();
    _preparationCancel = null;
  }
}
