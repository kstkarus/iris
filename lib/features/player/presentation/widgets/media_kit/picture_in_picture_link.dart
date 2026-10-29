part of '../media_kit_player_viewport_factory.dart';

/// Ties the player to the system's small window: tells it whether the video
/// plays and its shape, and plays, pauses or stops from its side.
class _PictureInPictureLink {
  _PictureInPictureLink(
    this._window, {
    required MediaKitPlayerEngine engine,
    required VoidCallback onSupported,
  }) : _engine = engine {
    _subscriptions = [
      _window.playPausePressed.listen((_) => _playOrPause()),
      // Closing the window ends the watching, as leaving the page would.
      _window.dismissed.listen((_) => _pause()),
      if (_window case final IOSPictureInPicture ios) ...[
        ios.playingRequested.listen((playing) => _setPlaying(playing)),
        ios.seekRequested.listen((request) => _seek(request)),
      ],
    ];
    _window.active.addListener(_onModeChanged);
    unawaited(
      _window
          .isSupported()
          .then((supported) {
            if (_disposed || !supported) return;
            this.supported = true;
            onSupported();
          })
          .catchError((Object error) {
            debugPrint('Picture-in-picture support check failed: $error');
          }),
    );
    follow();
  }

  final PictureInPicture _window;
  MediaKitPlayerEngine _engine;
  late final List<StreamSubscription<Object?>> _subscriptions;

  /// The player whose streams are followed; a new one comes with changed
  /// decoding preferences.
  Player? _player;
  List<StreamSubscription<Object?>> _playerSubscriptions = const [];
  bool _disposed = false;
  Player? _iosAttachedPlayer;
  Future<bool>? _entering;
  int? _reportedSecond;

  bool supported = false;

  ({String play, String pause}) _labels = (play: 'Play', pause: 'Pause');
  set labels(({String play, String pause}) labels) {
    if (labels == _labels) return;
    _labels = labels;
    _report();
  }

  set engine(MediaKitPlayerEngine engine) {
    _engine = engine;
    follow();
  }

  ValueListenable<bool> get active => _window.active;

  Future<bool> enter() => _entering ??= _enter().whenComplete(() {
    _entering = null;
  });

  Future<bool> _enter() async {
    if (_window case final IOSPictureInPicture ios) {
      final player = _player;
      final engine = _engine;
      if (player == null) return false;
      // Native VideoOutput must exist before AVKit attaches to its frames.
      await engine.videoController.platform.future.timeout(
        const Duration(seconds: 3),
      );
      final handle = await player.handle;
      if (_disposed || !identical(player, _player)) return false;
      if (!await ios.attachPlayer(handle)) return false;
      if (_disposed || !identical(player, _player)) return false;
      _iosAttachedPlayer = player;
      var entered = false;
      try {
        await engine.setPictureInPictureSubtitles(true);
        if (_disposed || !identical(player, _player)) return false;
        _report();
        await _reportPlayback();
        entered = await ios.enter();
        return entered;
      } finally {
        if (!entered && !_disposed && identical(player, _player)) {
          await engine.setPictureInPictureSubtitles(false);
        }
      }
    }
    return _window.enter();
  }

  void _onModeChanged() {
    if (_disposed || _window is! IOSPictureInPicture) return;
    unawaited(_engine.setPictureInPictureSubtitles(active.value));
  }

  /// Follows the engine's current player, if it changed.
  void follow() {
    if (_disposed) return;
    final player = _engine.hasPlayer ? _engine.player : null;
    if (identical(player, _player)) return;
    if (_iosAttachedPlayer != null) {
      _iosAttachedPlayer = null;
      _ignoreFailure(_window.clearPlayer());
    }
    _player = player;
    _reportedSecond = null;
    for (final subscription in _playerSubscriptions) {
      unawaited(subscription.cancel());
    }
    _playerSubscriptions = player == null
        ? const []
        : [
            player.stream.playing.listen((_) => _report()),
            player.stream.width.listen((_) => _report()),
            player.stream.height.listen((_) => _report()),
            if (_window is IOSPictureInPicture) ...[
              player.stream.duration.listen(
                (_) => _ignoreFailure(_reportPlayback()),
              ),
              player.stream.rate.listen(
                (_) => _ignoreFailure(_reportPlayback()),
              ),
              player.stream.position.listen((position) {
                if (_reportedSecond == position.inSeconds) return;
                _reportedSecond = position.inSeconds;
                _ignoreFailure(_reportPlayback());
              }),
            ],
          ];
    _report();
  }

  void _report() {
    final player = _player;
    if (_disposed || player == null) return;
    if (_window is IOSPictureInPicture &&
        !identical(player, _iosAttachedPlayer)) {
      return;
    }
    final state = player.state;
    final width = state.width;
    final height = state.height;
    unawaited(
      _window
          .setPlayer(
            playing: state.playing,
            aspectRatio:
                width != null && height != null && width > 0 && height > 0
                ? width / height
                : null,
            playLabel: _labels.play,
            pauseLabel: _labels.pause,
          )
          .catchError((Object error) {
            debugPrint('Picture-in-picture player update failed: $error');
          }),
    );
  }

  Future<void> _reportPlayback({Duration? position}) async {
    final player = _player;
    if (_disposed || player == null || !identical(player, _iosAttachedPlayer)) {
      return;
    }
    if (_window case final IOSPictureInPicture ios) {
      await ios.setPlayback(
        position: position ?? _engine.position,
        duration: player.state.duration,
        rate: player.state.rate,
      );
    }
  }

  void _setPlaying(bool playing) {
    final player = _player;
    if (_disposed || player == null || player.state.playing == playing) return;
    _ignoreFailure(playing ? player.play() : player.pause());
  }

  Future<void> _seek(({int id, Duration interval}) request) async {
    final player = _player;
    if (_disposed || player == null || _window is! IOSPictureInPicture) return;
    final ios = _window;
    try {
      var target = _engine.position + request.interval;
      if (target < Duration.zero) target = Duration.zero;
      final duration = player.state.duration;
      if (duration > Duration.zero && target > duration) target = duration;
      await _engine.seek(target);
      if (_disposed || !identical(player, _player)) return;
      await _reportPlayback(position: target);
    } catch (error) {
      debugPrint('Picture-in-picture seek failed: $error');
    } finally {
      if (!_disposed && identical(player, _player)) {
        _ignoreFailure(ios.completeSeek(request.id));
      }
    }
  }

  void _ignoreFailure(Future<void> future) {
    unawaited(
      future.catchError((Object error) {
        debugPrint('Picture-in-picture command failed: $error');
      }),
    );
  }

  void _playOrPause() {
    if (!_disposed && _engine.hasPlayer) {
      unawaited(_engine.player.playOrPause());
    }
  }

  void _pause() {
    if (!_disposed && _engine.hasPlayer) unawaited(_engine.player.pause());
  }

  void dispose() {
    _disposed = true;
    _window.active.removeListener(_onModeChanged);
    if (_window is IOSPictureInPicture) {
      unawaited(_engine.setPictureInPictureSubtitles(false));
    }
    for (final subscription in [..._subscriptions, ..._playerSubscriptions]) {
      unawaited(subscription.cancel());
    }
    unawaited(
      _window.clearPlayer().catchError((Object error) {
        debugPrint('Picture-in-picture cleanup failed: $error');
      }),
    );
  }
}
