import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/online_sources/domain/online_stream_choice.dart';
import 'package:iris/features/online_sources/domain/repositories/online_quality_preferences.dart';
import 'package:iris/features/player/domain/downloaded_player_source.dart';
import 'package:iris/features/player/domain/entities/no_playable_video_exception.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/shared/torrent/preparation_cancelled_exception.dart';
import 'package:iris/shared/torrent/video_file_extensions.dart';

class PlayerSourceCubit extends Cubit<PlayerSourceState> {
  PlayerSourceCubit({
    required this.args,
    required DownloadsRepository downloadsRepository,
    required PlayerRepository playerRepository,
    OnlineQualityPreferences? qualityPreferences,
  }) : _downloadsRepository = downloadsRepository,
       _playerRepository = playerRepository,
       _qualityPreferences = qualityPreferences,
       super(const PlayerSourceInitial());

  final AnimePlayerSourceArgs args;
  final DownloadsRepository _downloadsRepository;
  final PlayerRepository _playerRepository;
  final OnlineQualityPreferences? _qualityPreferences;

  PreparedDownloadSource? _source;
  Completer<void>? _preparation;
  StreamSubscription<Map<int, DownloadItem>>? _downloadsSubscription;
  Map<int, DownloadItem>? _downloads;
  bool _downloadsFailed = false;
  bool _closing = false;
  Future<bool>? _batch;

  Future<void> loadSource() async {
    if (_closing || state is PlayerSourceReady) return;
    _preparation?.complete();
    final preparation = _preparation = Completer<void>();
    emit(const PlayerSourceLoading());
    if (_downloadsSubscription == null || _downloadsFailed) _watchDownloads();

    try {
      final fileIndex = args.autoOpenFileIndex;
      if (args.preferDownloads && fileIndex != null) {
        final local = await _resumeDownload(fileIndex, preparation.future);
        if (preparation.isCompleted) return;
        if (local != null) {
          emit(
            PlayerSourceReady(
              local.files,
              localSessionId: local.sessionId,
              downloads: _downloads,
            ),
          );
          return;
        }
      }

      final source = await _prepareDownloads(preparation.future);
      if (preparation.isCompleted) {
        await _disposeSource(source);
        return;
      }
      final files = source == null
          ? await _playableFiles(preparation.future)
          : List<PlayerVideoFile>.unmodifiable(
              source.files.map(
                (file) => PlayerVideoFile(
                  index: file.index,
                  name: file.name,
                  size: file.size,
                  extension: file.episodeNumber == null
                      ? videoFileExtension(file.name)
                      : '',
                  episodeNumber: file.episodeNumber,
                  title: file.title,
                  duration: file.duration,
                ),
              ),
            );
      if (preparation.isCompleted) return;
      if (files.isEmpty) {
        await _disposeSource(source);
        throw const NoPlayableVideoException();
      }
      _source = source;
      if (source != null && _downloadsFailed) _watchDownloads();

      final wanted = _qualityPreferences?.downloading;
      emit(
        PlayerSourceReady(
          files,
          downloadSource: source,
          downloads: _downloads,
          quality: wanted == null || source == null
              ? null
              : closestQuality(source.qualities, wanted),
          selecting:
              args.initialDownloadMode &&
              files.length > 1 &&
              source != null &&
              (_downloads == null ||
                  files.any((file) => _downloads![file.index] == null)),
        ),
      );
    } on FormatException {
      if (!preparation.isCompleted) {
        emit(
          const PlayerSourceFailure(PlayerSourceFailureType.unsupportedSource),
        );
      }
    } on NoPlayableVideoException {
      if (!preparation.isCompleted) {
        emit(
          const PlayerSourceFailure(PlayerSourceFailureType.unsupportedSource),
        );
      }
    } on Object catch (error, stackTrace) {
      if (!preparation.isCompleted) {
        _log('Unable to prepare release.', error, stackTrace);
        emit(
          const PlayerSourceFailure(PlayerSourceFailureType.unableToPrepare),
        );
      }
    } finally {
      if (identical(_preparation, preparation)) _preparation = null;
    }
  }

  Future<PreparedDownloadSource?> _prepareDownloads(
    Future<void> cancelled,
  ) async {
    try {
      // For a torrent, preparation releases its native handle after reading
      // the files. This token can then enqueue files while the picker is open.
      return await _downloadsRepository.prepareSource(
        magnet: args.magnet,
        cancelled: cancelled,
      );
    } on FormatException {
      rethrow;
    } on PreparationCancelledException {
      rethrow;
    } on Object catch (error, stackTrace) {
      _log('Unable to prepare the release for downloads.', error, stackTrace);
      return null;
    }
  }

  /// Playback can still work when the downloads registry is unavailable.
  Future<List<PlayerVideoFile>> _playableFiles(Future<void> cancelled) async {
    final source = await _playerRepository.prepareSource(
      magnet: args.magnet,
      cancelled: cancelled,
    );
    await _playerRepository.disposePlayback(sessionId: source.sessionId);
    return source.files;
  }

  Future<PreparedPlayerSource?> _resumeDownload(
    int index,
    Future<void> cancelled,
  ) async {
    try {
      final Map<int, DownloadItem> items =
          _downloads ??
          await unlessCancelled(
            _downloadsRepository
                .watchSourceDownloads(magnet: args.magnet)
                .first,
            cancelled,
          );
      final item = items[index];
      if (item?.status != DownloadStatus.completed ||
          await unlessCancelled(
                _downloadsRepository.findCompletedById(id: item!.id),
                cancelled,
              ) ==
              null) {
        return null;
      }
      return downloadedPlayerSource(
        items.values.toList(),
        args.magnet,
        animeId: args.animeId,
        preferredFileIndex: index,
      );
    } on PreparationCancelledException {
      return null;
    } on Object catch (error, stackTrace) {
      _log('Unable to resume the completed download.', error, stackTrace);
      return null;
    }
  }

  void chooseQuality(int? quality) {
    final current = state;
    final qualities = _source?.qualities;
    if (current is! PlayerSourceReady ||
        current.addingBatch ||
        qualities == null ||
        qualities.isEmpty ||
        quality == current.quality ||
        (quality != null && !qualities.contains(quality))) {
      return;
    }
    emit(current.copyWith(quality: () => quality));
    _qualityPreferences?.setDownloading(quality).ignore();
  }

  void startSelection({int? index}) {
    final current = state;
    if (current is! PlayerSourceReady ||
        current.addingBatch ||
        current.files.length < 2 ||
        !current.hasNewDownloads ||
        (index != null &&
            (!current.files.any((file) => file.index == index) ||
                !current.canDownload(index)))) {
      return;
    }
    emit(current.copyWith(selecting: true, selected: {?index}));
  }

  void cancelSelection() {
    final current = state;
    if (current is! PlayerSourceReady || current.addingBatch) return;
    emit(
      current.copyWith(
        selecting: false,
        selected: const {},
        enqueueFailed: false,
      ),
    );
  }

  void toggleSelection(int index) {
    final current = state;
    if (current is! PlayerSourceReady) return;
    final selected = {...current.selected};
    if (!selected.remove(index)) selected.add(index);
    replaceSelection(selected);
  }

  void replaceSelection(Set<int> selected) {
    final current = state;
    if (current is! PlayerSourceReady ||
        !current.selecting ||
        current.addingBatch) {
      return;
    }
    emit(
      current.copyWith(
        selected: {
          for (final file in current.files)
            if (selected.contains(file.index) &&
                current.canDownload(file.index))
              file.index,
        },
      ),
    );
  }

  Future<bool> enqueue({int? singleIndex}) {
    final current = state;
    final source = _source;
    if (_closing || current is! PlayerSourceReady || source == null) {
      return Future.value(false);
    }
    if (_batch != null) return _batch!;
    final selected = singleIndex == null ? current.selected : {singleIndex};
    final files = [
      for (final file in source.files)
        if (selected.contains(file.index) && current.canDownload(file.index))
          file,
    ];
    if (files.isEmpty) return Future.value(false);
    return _batch = _enqueueFiles(
      current,
      source,
      files,
    ).whenComplete(() => _batch = null);
  }

  Future<bool> _enqueueFiles(
    PlayerSourceReady initial,
    PreparedDownloadSource source,
    List<DownloadableFile> files,
  ) async {
    emit(initial.copyWith(addingBatch: true, enqueueFailed: false));
    final failed = <int>{};
    for (final file in files) {
      if (_downloads?[file.index] != null) continue;
      try {
        final item = await _downloadsRepository.enqueueDownload(
          source: source,
          file: file,
          animeId: args.animeId,
          animeTitle: args.animeTitles.name,
          animeRussian: args.animeTitles.russian,
          animeEnglish: args.animeTitles.english,
          sourceTitle: args.sourceTitle,
          posterUrl: args.posterUrl,
          quality: initial.quality,
        );
        // The live snapshot may come after the enqueue result.
        _downloads = {
          ...?_downloads,
          file.index: _downloads?[file.index] ?? item,
        };
        _updateDownloads();
      } on Object catch (error, stackTrace) {
        _log('Unable to queue a selected file.', error, stackTrace);
        failed.add(file.index);
      }
    }
    failed.removeWhere((index) => _downloads?[index] != null);
    if (state case final PlayerSourceReady latest when !_closing) {
      emit(
        latest.copyWith(
          addingBatch: false,
          selecting: initial.selecting && failed.isNotEmpty,
          selected: initial.selecting ? failed : const {},
          enqueueFailed: failed.isNotEmpty,
        ),
      );
    }
    return failed.isEmpty;
  }

  void _watchDownloads() {
    _downloadsSubscription?.cancel().ignore();
    _downloadsFailed = false;
    _downloadsSubscription = _downloadsRepository
        .watchSourceDownloads(magnet: args.magnet)
        .listen(
          (downloads) {
            _downloads = Map.unmodifiable(downloads);
            _updateDownloads();
          },
          onError: (Object error, StackTrace stackTrace) {
            _downloadsFailed = true;
            _log('Unable to follow release downloads.', error, stackTrace);
          },
        );
  }

  void _updateDownloads() {
    if (_closing || state is! PlayerSourceReady) return;
    final current = state as PlayerSourceReady;
    emit(
      current.copyWith(
        downloads: _downloads,
        selected: current.selected
            .where((index) => _downloads?[index] == null)
            .toSet(),
      ),
    );
  }

  Future<void> _disposeSource(PreparedDownloadSource? source) async {
    if (source == null) return;
    try {
      await _downloadsRepository.disposePreparedSource(
        sourceToken: source.sourceToken,
      );
    } on Object catch (error, stackTrace) {
      _log('Unable to release the download source.', error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    _closing = true;
    _preparation?.complete();
    _preparation = null;
    // The already-requested files must reach the queue even if the page pops.
    await _batch;
    final source = _source;
    _source = null;
    await _disposeSource(source);
    try {
      await _downloadsSubscription?.cancel();
    } on Object catch (error, stackTrace) {
      _log('Unable to close the download status stream.', error, stackTrace);
    }
    return super.close();
  }

  void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'iris.player.source_cubit',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
