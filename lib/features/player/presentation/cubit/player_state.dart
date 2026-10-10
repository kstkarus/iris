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
  const PlayerPreparing({this.keepsPlayer = false});

  /// A file was already playing: the player stays on screen (and in full
  /// screen) while this one starts.
  final bool keepsPlayer;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerPreparing && other.keepsPlayer == keepsPlayer;
  }

  @override
  int get hashCode => keepsPlayer.hashCode;
}

final class PlayerReady extends PlayerState {
  const PlayerReady(
    this.session, {
    this.startPosition,
    this.showResumeNotice = false,
    this.startsOver = false,
    this.started = false,
    this.completed = false,
    this.watched = false,
  });

  final PlayerSession session;

  /// Where the file was opened (resume); null when it starts from zero.
  final Duration? startPosition;

  /// The resume notice is up: where playback picks up, and the way to
  /// start over instead.
  final bool showResumeNotice;

  /// The viewer chose to start from the beginning over [startPosition].
  final bool startsOver;

  /// The file is playing: its first frame was on screen.
  final bool started;

  /// The file played to its end.
  final bool completed;

  /// Playback reached the file's ending: it counts as watched.
  final bool watched;

  PlayerReady copyWith({
    bool? showResumeNotice,
    bool? startsOver,
    bool? started,
    bool? completed,
    bool? watched,
  }) {
    return PlayerReady(
      session,
      startPosition: startPosition,
      showResumeNotice: showResumeNotice ?? this.showResumeNotice,
      startsOver: startsOver ?? this.startsOver,
      started: started ?? this.started,
      completed: completed ?? this.completed,
      watched: watched ?? this.watched,
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
        other.startsOver == startsOver &&
        other.started == started &&
        other.completed == completed &&
        other.watched == watched;
  }

  @override
  int get hashCode => Object.hash(
    session,
    startPosition,
    showResumeNotice,
    startsOver,
    started,
    completed,
    watched,
  );
}

final class PlayerFailure extends PlayerState {
  const PlayerFailure();

  @override
  bool operator ==(Object other) => other is PlayerFailure;

  @override
  int get hashCode => runtimeType.hashCode;
}
