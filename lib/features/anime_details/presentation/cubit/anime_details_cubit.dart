import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_state.dart';

class AnimeDetailsCubit extends Cubit<AnimeDetailsState> {
  AnimeDetailsCubit({
    required String animeId,
    required AnimeDetailsRepository repository,
  }) : _animeId = animeId,
       _repository = repository,
       super(const AnimeDetailsInitial());

  final String _animeId;
  final AnimeDetailsRepository _repository;

  Future<void> loadAnime() async {
    emit(const AnimeDetailsLoading());

    try {
      final details = await _repository.fetchAnimeDetails(_animeId);
      emit(AnimeDetailsSuccess(details));
    } catch (_) {
      emit(const AnimeDetailsFailure());
    }
  }
}
