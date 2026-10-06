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
  const PlayerPreparing({required this.progress, this.keepsPlayer = false});

  final PlayerLaunchProgress progress;

  /// A file was already playing: the player stays on screen (and in full
  /// screen) while this one starts.
  final bool keepsPlayer;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerPreparing &&
        other.progress == progress &&
        other.keepsPlayer == keepsPlayer;
  }

  @override
  int get hashCode => Object.hash(progress, keepsPlayer);
}

final class PlayerReady extends PlayerState {
  const PlayerReady(
    this.session, {
    this.startPosition,
    this.showResumeNotice = false,
    this.completed = false,
  });

  final PlayerSession session;

  /// Where the file was opened (resume); null when it starts from zero.
  final Duration? startPosition;
  final bool showResumeNotice;

  /// The file played to its end.
  final bool completed;

  PlayerReady copyWith({bool? showResumeNotice, bool? completed}) {
    return PlayerReady(
      session,
      startPosition: startPosition,
      showResumeNotice: showResumeNotice ?? this.showResumeNotice,
      completed: completed ?? this.completed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerReady &&
        other.session == session &&
        other.startPosition == startPosition &&
        other.showResumeNotice == showResumeNotice &&
        other.completed == completed;
  }

  @override
  int get hashCode =>
      Object.hash(session, startPosition, showResumeNotice, completed);
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
