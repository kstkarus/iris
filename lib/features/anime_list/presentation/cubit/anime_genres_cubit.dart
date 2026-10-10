import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/anime_list/domain/entities/anime_genre.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_genres_repository.dart';

sealed class AnimeGenresState {
  const AnimeGenresState();
}

final class AnimeGenresIdle extends AnimeGenresState {
  const AnimeGenresIdle();
}

final class AnimeGenresLoading extends AnimeGenresState {
  const AnimeGenresLoading();
}

/// The filter section is left out: genres are a nicety, not worth an
/// error in the middle of the filters.
final class AnimeGenresUnavailable extends AnimeGenresState {
  const AnimeGenresUnavailable();
}

final class AnimeGenresLoaded extends AnimeGenresState {
  const AnimeGenresLoaded(this.genres);

  final List<AnimeGenre> genres;
}

/// The genres to filter by, asked for the first time the filters open.
class AnimeGenresCubit extends Cubit<AnimeGenresState> {
  AnimeGenresCubit({required AnimeGenresRepository repository})
    : _repository = repository,
      super(const AnimeGenresIdle());

  final AnimeGenresRepository _repository;

  Future<void> load() async {
    if (state is AnimeGenresLoading || state is AnimeGenresLoaded) return;
    emit(const AnimeGenresLoading());
    try {
      final genres = await _repository.genres();
      if (!isClosed) {
        emit(
          genres.isEmpty
              ? const AnimeGenresUnavailable()
              : AnimeGenresLoaded(genres),
        );
      }
    } on Exception {
      if (!isClosed) emit(const AnimeGenresUnavailable());
    }
  }
}
