import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';
import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';
import 'package:iris/features/saved_torrents/presentation/cubit/saved_torrents_state.dart';

class SavedTorrentsCubit extends Cubit<SavedTorrentsState> {
  SavedTorrentsCubit({
    required SavedTorrentsRepository repository,
    this.highlightDuration = const Duration(seconds: 2),
  }) : _repository = repository,
       super(const SavedTorrentsState());

  final SavedTorrentsRepository _repository;
  final Duration highlightDuration;
  StreamSubscription<List<SavedTorrent>>? _subscription;
  Timer? _highlightTimer;

  void load() {
    if (_subscription != null) return;
    _subscription = _repository.watchTorrents().listen(
      (torrents) {
        if (!isClosed) {
          emit(state.copyWith(isLoading: false, torrents: torrents));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'Unable to read saved torrents.',
          name: 'iris.saved_torrents.cubit',
          error: error,
          stackTrace: stackTrace,
        );
        if (!isClosed) emit(state.copyWith(isLoading: false));
      },
    );
  }

  /// Saves a magnet link. The caller shows feedback based on the result.
  Future<SaveTorrentResult> add({required String magnet, String? title}) async {
    final result = await _repository.add(magnet: magnet, title: title);
    switch (result) {
      case SaveTorrentAdded(:final torrent):
        _highlight(torrent.infoHash);
      case SaveTorrentDuplicate(:final existing):
        _highlight(existing.infoHash);
      case SaveTorrentInvalidMagnet():
        break;
    }
    return result;
  }

  Future<void> rename(String infoHash, String title) {
    return _repository.rename(infoHash: infoHash, title: title);
  }

  Future<void> delete(String infoHash) {
    return _repository.delete(infoHash: infoHash);
  }

  /// Moves the torrent to the top of the list when the user opens it.
  Future<void> markOpened(String infoHash) {
    return _repository.markOpened(infoHash: infoHash);
  }

  void _highlight(String infoHash) {
    _highlightTimer?.cancel();
    if (isClosed) return;
    emit(state.copyWith(highlightedInfoHash: infoHash));
    _highlightTimer = Timer(highlightDuration, () {
      if (!isClosed) emit(state.copyWith(clearHighlight: true));
    });
  }

  @override
  Future<void> close() async {
    _highlightTimer?.cancel();
    await _subscription?.cancel();
    return super.close();
  }
}
