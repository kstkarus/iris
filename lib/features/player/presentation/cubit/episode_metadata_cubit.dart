import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/player/domain/entities/episode_metadata.dart';
import 'package:iris/features/player/domain/repositories/episode_metadata_repository.dart';

/// Loads optional episode titles and filler/recap flags for one anime.
///
/// The first page loads on open; once the release's episode list is known,
/// [ensureLoadedUpTo] fetches further pages if the release goes past 100.
class EpisodeMetadataCubit extends Cubit<Map<int, EpisodeMetadata>> {
  EpisodeMetadataCubit({
    required String animeId,
    required EpisodeMetadataRepository repository,
  }) : _animeId = animeId,
       _repository = repository,
       super(const {});

  final String _animeId;
  final EpisodeMetadataRepository _repository;
  int _requestedUpTo = 0;

  Future<void> load({int? upToEpisode}) async {
    final target = upToEpisode != null && upToEpisode > 0 ? upToEpisode : 1;
    if (target <= _requestedUpTo) return;
    _requestedUpTo = target;
    final loaded = await _repository.findForAnime(
      animeId: _animeId,
      upToEpisode: target,
    );
    if (isClosed) return;
    if (loaded.isNotEmpty) {
      emit(loaded);
    }
  }

  Future<void> ensureLoadedUpTo(int? episode) {
    if (episode == null || episode <= _requestedUpTo) return Future.value();
    return load(upToEpisode: episode);
  }
}
