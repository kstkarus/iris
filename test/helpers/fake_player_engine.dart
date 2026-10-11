import 'dart:async';

import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/entities/player_track_preferences.dart';
import 'package:iris/features/player/presentation/playback/player_engine.dart';

/// Records what the session owner asks the media player to do. Hold
/// [stopGate] / [closeGate] open to simulate a player that has not released
/// its stream yet.
class FakePlayerEngine implements PlayerEngine {
  final calls = <String>[];
  final _events = StreamController<PlayerEngineEvent>.broadcast();

  Completer<void>? stopGate;
  Completer<void>? closeGate;
  Duration? lastStartPosition;
  PlayerTrackPreferences? lastPreferredTracks;
  List<PlayerSkipSegment>? lastSkipTimes;

  /// Skip times were announced as on their way and have not come yet.
  bool skipTimesExpected = false;

  void emit(PlayerEngineEvent event) => _events.add(event);

  @override
  Stream<PlayerEngineEvent> get events => _events.stream;

  @override
  Future<void> open(
    PlayerSession session, {
    Duration? startPosition,
    PlayerTrackPreferences? preferredTracks,
  }) async {
    lastStartPosition = startPosition;
    lastPreferredTracks = preferredTracks;
    calls.add('open ${session.streamUrl}');
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek $position');
  }

  @override
  void expectSkipTimes() => skipTimesExpected = true;

  @override
  void useSkipTimes(List<PlayerSkipSegment> segments) {
    skipTimesExpected = false;
    lastSkipTimes = segments;
    calls.add('skip times ${segments.length}');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    await stopGate?.future;
    calls.add('stopped');
  }

  @override
  Future<void> close() async {
    calls.add('close');
    await closeGate?.future;
    calls.add('closed');
    await _events.close();
  }
}
