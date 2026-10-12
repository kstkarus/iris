import 'package:iris/features/characters/domain/entities/anime_character.dart';
import 'package:iris/shared/utils/equality.dart';

sealed class AnimeCharactersState {
  const AnimeCharactersState();
}

final class AnimeCharactersLoading extends AnimeCharactersState {
  const AnimeCharactersLoading();

  @override
  bool operator ==(Object other) => other is AnimeCharactersLoading;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class AnimeCharactersLoaded extends AnimeCharactersState {
  const AnimeCharactersLoaded(this.characters);

  final List<AnimeCharacter> characters;

  @override
  bool operator ==(Object other) =>
      other is AnimeCharactersLoaded && sameList(other.characters, characters);

  @override
  int get hashCode => Object.hashAll(characters);
}

final class AnimeCharactersFailure extends AnimeCharactersState {
  const AnimeCharactersFailure();

  @override
  bool operator ==(Object other) => other is AnimeCharactersFailure;

  @override
  int get hashCode => runtimeType.hashCode;
}
