import 'package:iris/features/player/domain/entities/player_session.dart';

sealed class PlayerLaunchUpdate {
  const PlayerLaunchUpdate();
}

final class PlayerLaunchReadyUpdate extends PlayerLaunchUpdate {
  const PlayerLaunchReadyUpdate(this.session);

  final PlayerSession session;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerLaunchReadyUpdate && other.session == session;
  }

  @override
  int get hashCode => session.hashCode;
}

final class PlayerLaunchFailureUpdate extends PlayerLaunchUpdate {
  const PlayerLaunchFailureUpdate();

  @override
  bool operator ==(Object other) => other is PlayerLaunchFailureUpdate;

  @override
  int get hashCode => runtimeType.hashCode;
}
