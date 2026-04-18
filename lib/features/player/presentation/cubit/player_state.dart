import 'package:iris/features/player/domain/entities/player_launch_failure.dart';
import 'package:iris/features/player/domain/entities/player_launch_progress.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';

sealed class PlayerState {
  const PlayerState();
}

final class PlayerInitial extends PlayerState {
  const PlayerInitial();

  @override
  bool operator ==(Object other) => other is PlayerInitial;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class PlayerPreparing extends PlayerState {
  const PlayerPreparing({required this.progress});

  final PlayerLaunchProgress progress;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerPreparing && other.progress == progress;
  }

  @override
  int get hashCode => progress.hashCode;
}

final class PlayerReady extends PlayerState {
  const PlayerReady(this.session);

  final PlayerSession session;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerReady && other.session == session;
  }

  @override
  int get hashCode => session.hashCode;
}

final class PlayerFailure extends PlayerState {
  const PlayerFailure(this.type);

  final PlayerLaunchFailure type;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerFailure && other.type == type;
  }

  @override
  int get hashCode => type.hashCode;
}
