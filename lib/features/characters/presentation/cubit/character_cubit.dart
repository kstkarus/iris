import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/characters/domain/repositories/characters_repository.dart';
import 'package:iris/features/characters/presentation/cubit/character_state.dart';

class CharacterCubit extends Cubit<CharacterState> {
  CharacterCubit({
    required String characterId,
    required CharactersRepository repository,
  }) : _characterId = characterId,
       _repository = repository,
       super(const CharacterLoading());

  final String _characterId;
  final CharactersRepository _repository;

  Future<void> load() async {
    if (state is! CharacterLoading) emit(const CharacterLoading());
    try {
      final details = await _repository.character(_characterId);
      if (isClosed) return;
      emit(CharacterLoaded(details));
    } on Object {
      if (isClosed) return;
      emit(const CharacterFailure());
    }
  }
}
