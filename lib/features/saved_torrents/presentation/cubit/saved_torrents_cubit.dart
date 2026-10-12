import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';
import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';
import 'package:iris/features/saved_torrents/presentation/cubit/saved_torrents_state.dart';

/// The torrents the user added to one anime.
class SavedTorrentsCubit extends Cubit<SavedTorrentsState> {
  SavedTorrentsCubit({
    required String animeId,
    required SavedTorrentsRepository repository,
    this.highlightDuration = const Duration(seconds: 2),
  }) : _animeId = animeId,
       _repository = repository,
       super(const SavedTorrentsState());

  final String _animeId;
  final SavedTorrentsRepository _repository;
  final Duration highlightDuration;
  StreamSubscription<List<SavedTorrent>>? _subscription;
  Timer? _highlightTimer;

  void load() {
    if (_subscription != null) return;
    _subscription = _repository
        .watchTorrents(_animeId)
        .listen(
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

  /// Adds a magnet link. The caller shows feedback based on the result.
  Future<SaveTorrentResult> add(String magnet) async {
    final result = await _repository.add(animeId: _animeId, magnet: magnet);
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

  Future<void> rename(SavedTorrent torrent, String title) =>
      _repository.rename(torrent, title);

  /// Removes the torrent, for [restore] to undo.
  Future<void> delete(SavedTorrent torrent) => _repository.delete(torrent);

  Future<void> restore(SavedTorrent torrent) => _repository.restore(torrent);

  /// Moves the torrent to the top of the list when the user opens it.
  Future<void> markOpened(SavedTorrent torrent) =>
      _repository.markOpened(torrent);

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
