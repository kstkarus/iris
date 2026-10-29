import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';

/// Covers are optional: resolving them never delays opening local history.
class ContinueWatchingPostersCubit extends Cubit<Map<String, String>> {
  ContinueWatchingPostersCubit({required AnimeDetailsRepository repository})
    : _repository = repository,
      super(const {});

  final AnimeDetailsRepository _repository;
  final _loading = <String>{};

  Future<void> load(
    List<WatchProgress> items,
    Map<String, String> known,
  ) async {
    if (isClosed) return;
    final ids = {
      for (final item in items)
        if (item.hasAnime) item.animeId,
    };
    final available = {
      for (final id in ids)
        if (known[id]?.isNotEmpty ?? false) id: known[id]!,
    };
    if (available.isNotEmpty) emit(Map.unmodifiable({...state, ...available}));
    await Future.wait([
      for (final id in ids)
        if (!state.containsKey(id) && _loading.add(id)) _load(id),
    ]);
  }

  Future<void> _load(String id) async {
    try {
      final details = await _repository.fetchAnimeDetails(id);
      if (!isClosed) {
        emit(Map.unmodifiable({...state, id: details.anime.posterUrl}));
      }
    } catch (_) {
      // Offline history remains usable; another opening may retry its cover.
    } finally {
      _loading.remove(id);
    }
  }
}
