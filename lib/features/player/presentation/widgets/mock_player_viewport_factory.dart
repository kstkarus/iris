import 'dart:async';

import 'package:flutter/material.dart';

import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/entities/player_track_preferences.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/playback/player_engine.dart';
import 'package:iris/features/player/presentation/widgets/player_countdown.dart';
import 'package:iris/features/player/presentation/widgets/player_episodes_drawer.dart';
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
    required PlayerChrome chrome,
    PlayerInputMode input = PlayerInputMode.pointer,
    PlayerNextFile? next,
  }) {
    return _MockPlayerChrome(chrome: chrome);
  }
}

/// A black surface with the chrome's title, notice, way back and episodes
/// drawer, so the app's flows can be driven without a media engine.
class _MockPlayerChrome extends StatefulWidget {
  const _MockPlayerChrome({required this.chrome});

  final PlayerChrome chrome;

  @override
  State<_MockPlayerChrome> createState() => _MockPlayerChromeState();
}

class _MockPlayerChromeState extends State<_MockPlayerChrome> {
  bool _episodesOpen = false;

  void _setEpisodesOpen(bool open) => setState(() => _episodesOpen = open);

  @override
  Widget build(BuildContext context) {
    final chrome = widget.chrome;
    final episodes = chrome.episodes;
    final notice = chrome.notice;
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
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
        ),
        Positioned(
          left: 24,
          top: 20,
          right: 24,
          child: Row(
            children: [
              IconButton(
                key: const Key('player_back_button'),
                color: Colors.white,
                icon: const PixelIcon(PixelGlyph.arrowLeft),
                onPressed: chrome.onBack,
              ),
              Expanded(
                child: Text(
                  chrome.title,
                  key: const Key('player_title'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              if (episodes != null)
                IconButton(
                  key: const Key('player_episodes_button'),
                  color: Colors.white,
                  icon: const PixelIcon(PixelGlyph.episodes),
                  onPressed: () => _setEpisodesOpen(true),
                ),
            ],
          ),
        ),
        if (notice != null)
          Positioned(
            left: 24,
            bottom: 24,
            child: PlayerCountdown(
              duration: notice.timeout,
              onElapsed: notice.onTimeout,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notice.message,
                    style: const TextStyle(color: Colors.white),
                  ),
                  TextButton(
                    key: const Key('player_notice_action'),
                    onPressed: notice.onAction,
                    child: Text(notice.actionLabel),
                  ),
                ],
              ),
            ),
          ),
        if (_episodesOpen && episodes != null)
          PlayerEpisodesDrawer(
            onClose: () => _setEpisodesOpen(false),
            builder: episodes,
            caption: chrome.episodesCaption,
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
  final ValueNotifier<double> playbackRate = ValueNotifier(1);

  @override
  void setPlaybackRate(double rate) => playbackRate.value = rate;

  @override
  void holdFastForward(bool held) {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> close() {
    playbackRate.dispose();
    return _events.close();
  }
}
