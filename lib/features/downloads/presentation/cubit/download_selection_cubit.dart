import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_state.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';
import 'package:iris/features/online_sources/domain/online_stream_choice.dart';
import 'package:iris/features/online_sources/domain/repositories/online_quality_preferences.dart';

class DownloadSelectionCubit extends Cubit<DownloadSelectionState> {
  DownloadSelectionCubit({
    required this.args,
    required DownloadsRepository repository,
    OnlineQualityPreferences? qualityPreferences,
  }) : _repository = repository,
       _qualityPreferences = qualityPreferences,
       super(const DownloadSelectionInitial());

  final DownloadSelectionArgs args;
  final DownloadsRepository _repository;

  /// Remembers the quality last chosen for downloading online episodes.
  final OnlineQualityPreferences? _qualityPreferences;
  PreparedDownloadSource? _source;
  int _attempt = 0;
  Completer<void>? _preparationCancel;

  Future<void> load() async {
    final attempt = ++_attempt;
    _cancelPreparation();
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
      emit(DownloadSelectionReady(source, quality: _startingQuality(source)));
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
    if (current is! DownloadSelectionReady) return;
    emit(DownloadSelectionReady(current.source, quality: quality));
    unawaited(_qualityPreferences?.setDownloading(quality));
  }

  Future<void> enqueue(DownloadableFile file) async {
    final source = _source;
    final current = state;
    if (source == null || current is! DownloadSelectionReady) return;
    final quality = current.quality;
    emit(
      DownloadSelectionEnqueuing(source: source, file: file, quality: quality),
    );
    try {
      final item = await _repository.enqueueDownload(
        source: source,
        file: file,
        animeId: args.animeId,
        animeTitle: args.animeTitle,
        sourceTitle: args.sourceTitle,
        quality: quality,
      );
      _source = null;
      if (!isClosed) emit(DownloadSelectionQueued(item));
    } catch (error, stackTrace) {
      developer.log(
        'Unable to enqueue selected torrent file.',
        name: 'iris.downloads.selection',
        error: error,
        stackTrace: stackTrace,
      );
      if (!isClosed) {
        emit(
          const DownloadSelectionFailure(
            DownloadSelectionFailureType.unableToQueue,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    _attempt++;
    _cancelPreparation();
    final source = _source;
    _source = null;
    if (source != null) {
      await _repository.disposePreparedSource(sourceToken: source.sourceToken);
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
