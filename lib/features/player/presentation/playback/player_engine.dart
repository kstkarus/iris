import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/entities/player_track_preferences.dart';

/// What the media player reports back to the session owner.
sealed class PlayerEngineEvent {
  const PlayerEngineEvent();
}

/// The playback position; [flush] asks to persist it right away (pause,
/// end of file).
final class PlayerEngineProgress extends PlayerEngineEvent {
  const PlayerEngineProgress(
    this.position,
    this.duration, {
    this.flush = false,
  });

  final Duration position;
  final Duration duration;
  final bool flush;
}

/// The file played to its end.
final class PlayerEngineCompleted extends PlayerEngineEvent {
  const PlayerEngineCompleted();
}

/// The user picked an audio or subtitle track.
final class PlayerEngineTracksChosen extends PlayerEngineEvent {
  const PlayerEngineTracksChosen(this.preferences);

  final PlayerTrackPreferences preferences;
}

/// The page's media player. One instance lives as long as the player page,
/// so switching files, layouts or full screen never recreates it.
abstract interface class PlayerEngine {
  Stream<PlayerEngineEvent> get events;

  /// Opens a file's stream, at [startPosition] when resuming.
  Future<void> open(
    PlayerSession session, {
    Duration? startPosition,
    PlayerTrackPreferences? preferredTracks,
  });

  Future<void> seek(Duration position);

  /// Opening/ending times looked up for the opened file. The file's own
  /// chapters, when they name them, take precedence.
  void useSkipTimes(List<PlayerSkipSegment> segments);

  /// Stops playback and closes the stream connection; the player stays
  /// for the next file. Completes only once the stream is released, so the
  /// session owner can tear the stream down safely afterwards.
  Future<void> stop();

  /// Releases the player for good.
  Future<void> close();
}
