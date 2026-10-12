import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/characters/domain/repositories/characters_repository.dart';
import 'package:iris/features/characters/presentation/cubit/anime_characters_state.dart';

class AnimeCharactersCubit extends Cubit<AnimeCharactersState> {
  AnimeCharactersCubit({
    required String animeId,
    required CharactersRepository repository,
  }) : _animeId = animeId,
       _repository = repository,
       super(const AnimeCharactersLoading());

  final String _animeId;
  final CharactersRepository _repository;

  Future<void> load() async {
    if (state is! AnimeCharactersLoading) emit(const AnimeCharactersLoading());
    try {
      final characters = await _repository.animeCharacters(_animeId);
      if (isClosed) return;
      emit(AnimeCharactersLoaded(characters));
    } on Object {
      if (isClosed) return;
      emit(const AnimeCharactersFailure());
    }
  }
}
