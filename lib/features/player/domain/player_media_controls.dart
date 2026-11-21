enum PlayerMediaCommand {
  play,
  pause,
  togglePlayPause,
  next,
  seekForward,
  seekBackward,
  seekTo,
}

typedef PlayerMediaTitles = ({String title, String episode});

typedef PlayerMediaPlayback = ({
  Duration position,
  Duration duration,
  bool playing,
  bool buffering,
  double rate,
});

typedef PlayerMediaCommandHandler =
    Future<void> Function(PlayerMediaCommand command, Duration? position);

/// The system media session for one player page.
abstract interface class PlayerMediaControls {
  Future<void> update({
    required PlayerMediaTitles titles,
    required PlayerMediaPlayback playback,
    required bool canNext,
    required PlayerMediaCommandHandler onCommand,
  });

  Future<void> deactivate();
}

class NoPlayerMediaControls implements PlayerMediaControls {
  const NoPlayerMediaControls();

  @override
  Future<void> update({
    required PlayerMediaTitles titles,
    required PlayerMediaPlayback playback,
    required bool canNext,
    required PlayerMediaCommandHandler onCommand,
  }) async {}

  @override
  Future<void> deactivate() async {}
}
