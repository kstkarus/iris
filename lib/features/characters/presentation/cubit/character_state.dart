import 'package:iris/features/characters/domain/entities/character_details.dart';

sealed class CharacterState {
  const CharacterState();
}

final class CharacterLoading extends CharacterState {
  const CharacterLoading();

  @override
  bool operator ==(Object other) => other is CharacterLoading;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class CharacterLoaded extends CharacterState {
  const CharacterLoaded(this.details);

  final CharacterDetails details;

  @override
  bool operator ==(Object other) =>
      other is CharacterLoaded && other.details == details;

  @override
  int get hashCode => details.hashCode;
}

final class CharacterFailure extends CharacterState {
  const CharacterFailure();

  @override
  bool operator ==(Object other) => other is CharacterFailure;

  @override
  int get hashCode => runtimeType.hashCode;
}
