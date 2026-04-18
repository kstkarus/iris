import 'package:iris/features/player/domain/entities/prepared_player_source.dart';

sealed class PlayerSourceState {
  const PlayerSourceState();
}

final class PlayerSourceInitial extends PlayerSourceState {
  const PlayerSourceInitial();

  @override
  bool operator ==(Object other) => other is PlayerSourceInitial;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class PlayerSourceLoading extends PlayerSourceState {
  const PlayerSourceLoading();

  @override
  bool operator ==(Object other) => other is PlayerSourceLoading;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class PlayerSourceReady extends PlayerSourceState {
  const PlayerSourceReady(this.preparedSource);

  final PreparedPlayerSource preparedSource;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerSourceReady && other.preparedSource == preparedSource;
  }

  @override
  int get hashCode => preparedSource.hashCode;
}

enum PlayerSourceFailureType { unsupportedSource, unableToPrepare }

final class PlayerSourceFailure extends PlayerSourceState {
  const PlayerSourceFailure(this.type);

  final PlayerSourceFailureType type;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerSourceFailure && other.type == type;
  }

  @override
  int get hashCode => type.hashCode;
}
