import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_state.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';

class DownloadSelectionCubit extends Cubit<DownloadSelectionState> {
  DownloadSelectionCubit({
    required this.args,
    required DownloadsRepository repository,
  }) : _repository = repository,
       super(const DownloadSelectionInitial());

  final DownloadSelectionArgs args;
  final DownloadsRepository _repository;
  PreparedDownloadSource? _source;
  int _attempt = 0;

  Future<void> load() async {
    final attempt = ++_attempt;
    emit(const DownloadSelectionLoading());
    try {
      final source = await _repository.prepareSource(magnet: args.magnet);
      if (!_isCurrent(attempt)) {
        await _repository.disposePreparedSource(
          sourceToken: source.sourceToken,
        );
        return;
      }
      _source = source;
      emit(DownloadSelectionReady(source));
    } on FormatException {
      if (_isCurrent(attempt)) {
        emit(
          const DownloadSelectionFailure(
            DownloadSelectionFailureType.unsupported,
          ),
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Unable to prepare torrent files for download.',
        name: 'iris.downloads.selection',
        error: error,
        stackTrace: stackTrace,
      );
      if (_isCurrent(attempt)) {
        emit(
          const DownloadSelectionFailure(
            DownloadSelectionFailureType.unableToPrepare,
          ),
        );
      }
    }
  }

  Future<void> enqueue(DownloadableFile file) async {
    final source = _source;
    if (source == null || state is DownloadSelectionEnqueuing) return;
    emit(DownloadSelectionEnqueuing(source: source, file: file));
    try {
      final item = await _repository.enqueueDownload(
        source: source,
        file: file,
        animeId: args.animeId,
        animeTitle: args.animeTitle,
        sourceTitle: args.sourceTitle,
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
    final source = _source;
    _source = null;
    if (source != null) {
      await _repository.disposePreparedSource(sourceToken: source.sourceToken);
    }
    return super.close();
  }

  bool _isCurrent(int attempt) => !isClosed && attempt == _attempt;
}
