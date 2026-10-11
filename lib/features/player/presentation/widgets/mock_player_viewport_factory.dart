import 'dart:async';

import 'package:flutter/material.dart';

import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/entities/player_track_preferences.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/playback/player_engine.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

class MockPlayerViewportFactory implements PlayerViewportFactory {
  const MockPlayerViewportFactory();

  /// The mock "plays" every file to this point of a 24-minute episode, so
  /// watch progress can be exercised without a media engine.
  static const mockPosition = Duration(minutes: 5);
  static const mockDuration = Duration(minutes: 24);

  @override
  PlayerEngine createEngine({
    required PlayerSubtitlePreferencesCubit subtitlePreferences,
    required PlayerDecodingPreferencesCubit decodingPreferences,
  }) {
    return MockPlayerEngine();
  }

  @override
  Widget build({
    required PlayerEngine engine,
    PlayerNextFile? next,
    PlayerChrome? chrome,
  }) {
    final surface = Center(
      child: Container(
        key: const Key('mock_player_surface'),
        width: double.infinity,
        height: 220,
        color: Colors.black,
        alignment: Alignment.center,
        child: const Text(
          'Mock Player Surface',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
    if (chrome == null) return surface;
    return Stack(
      fit: StackFit.expand,
      children: [
        surface,
        Positioned(
          left: 24,
          top: 20,
          child: IconButton(
            key: const Key('player_back_button'),
            color: Colors.white,
            icon: const PixelIcon(PixelGlyph.arrowLeft),
            onPressed: chrome.onBack,
          ),
        ),
      ],
    );
  }
}

/// Reports [MockPlayerViewportFactory.mockPosition] for every opened file.
class MockPlayerEngine implements PlayerEngine {
  final _events = StreamController<PlayerEngineEvent>.broadcast();

  @override
  Stream<PlayerEngineEvent> get events => _events.stream;

  @override
  Future<void> open(
    PlayerSession session, {
    Duration? startPosition,
    PlayerTrackPreferences? preferredTracks,
  }) async {
    if (_events.isClosed) return;
    _events.add(
      const PlayerEngineProgress(
        MockPlayerViewportFactory.mockPosition,
        MockPlayerViewportFactory.mockDuration,
        flush: true,
      ),
    );
    _events.add(const PlayerEnginePlaybackStarted());
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  void expectSkipTimes() {}

  @override
  void useSkipTimes(List<PlayerSkipSegment> segments) {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> close() => _events.close();
}
