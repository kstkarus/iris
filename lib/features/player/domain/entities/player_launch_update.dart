import 'package:iris/features/player/domain/entities/player_launch_failure.dart';
import 'package:iris/features/player/domain/entities/player_launch_progress.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';

sealed class PlayerLaunchUpdate {
  const PlayerLaunchUpdate();
}

final class PlayerLaunchProgressUpdate extends PlayerLaunchUpdate {
  const PlayerLaunchProgressUpdate(this.progress);

  final PlayerLaunchProgress progress;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerLaunchProgressUpdate && other.progress == progress;
  }

  @override
  int get hashCode => progress.hashCode;
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
  const PlayerLaunchFailureUpdate(this.failure);

  final PlayerLaunchFailure failure;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerLaunchFailureUpdate && other.failure == failure;
  }

  @override
  int get hashCode => failure.hashCode;
}
