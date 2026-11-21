part of 'media_kit_player_engine.dart';

/// Serializes native commands while letting a new intent interrupt a ramp.
class _MediaKitAudioTransport {
  _MediaKitAudioTransport(this._player, this._userVolume, this._duration)
    : _volume = _player.state.volume;

  static const _steps = 4;
  final Player _player;
  final ValueListenable<double> _userVolume;
  final Duration _duration;
  final _commands = SerialQueue();
  double? _volume;
  bool? _requestedPlaying;
  int _generation = 0;
  int _pendingRequests = 0;
  Timer? _timer;
  Completer<void>? _tick;

  int get generation => _generation;
  Future<void>? get pending => _pendingRequests == 0 ? null : _commands.idle;

  bool get _isPlaying => _player.state.playing && !_player.state.completed;
  bool get wantsToPlay => _requestedPlaying ?? _isPlaying;

  void cancel() {
    _generation++;
    _requestedPlaying = null;
    _finishTick();
  }

  Future<void> setPlaying(bool playing, {required bool fade}) =>
      _request(playing, fade: fade, force: !fade);

  // A volume change completes the requested play/pause without the ramp.
  Future<void> applyUserVolume() => _request(_requestedPlaying, fade: false);

  Future<void> restore({bool pauseIfFading = false}) async {
    if (pending == null && _volume == _userVolume.value) {
      cancel();
      return;
    }
    try {
      await _request(null, fade: false, pauseIfFading: pauseIfFading);
    } catch (error, stackTrace) {
      _log(
        'Failed to pause before restoring playback volume.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _request(
    bool? playing, {
    required bool fade,
    bool force = false,
    bool pauseIfFading = false,
  }) {
    cancel();
    _requestedPlaying = playing;
    final generation = _generation;
    bool current() => generation == _generation;

    _pendingRequests++;
    return _commands
        .run(() async {
          if (!current()) return;
          final wasPlaying = _isPlaying;
          final volume = _userVolume.value;
          final ramp = fade && volume > 0 && _duration > Duration.zero;
          try {
            if (playing == true) {
              if (!wasPlaying || force) {
                await _setVolume(ramp ? 0 : volume);
                if (!current()) return;
                await _player.play();
              }
              if (ramp && current()) await _fadeTo(volume, generation);
            } else if (playing == false) {
              if (ramp && wasPlaying) await _fadeTo(0, generation);
              if (current() && (wasPlaying || force)) await _player.pause();
            } else if (pauseIfFading && wasPlaying && _volume != volume) {
              await _player.pause();
            }
          } finally {
            if (current()) {
              await _setVolume(volume);
              if (current()) _requestedPlaying = null;
            }
          }
        })
        .whenComplete(() {
          _pendingRequests--;
        });
  }

  Future<void> _fadeTo(double target, int generation) async {
    final from = _volume ?? _player.state.volume;
    if (from == target) return;
    for (var step = 1; step <= _steps; step++) {
      final tick = _tick = Completer<void>();
      _timer = Timer(_duration ~/ _steps, _finishTick);
      await tick.future;
      if (generation != _generation) return;
      await _setVolume(from + (target - from) * step / _steps);
      if (generation != _generation) return;
    }
  }

  void _finishTick() {
    _timer?.cancel();
    _timer = null;
    _tick?.complete();
    _tick = null;
  }

  Future<void> _setVolume(double volume) async {
    if (volume == _volume) return;
    try {
      await _player.setVolume(volume);
      _volume = volume;
    } catch (error, stackTrace) {
      _volume = null;
      _log('Failed to set playback volume.', error, stackTrace);
    }
  }

  void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'iris.player.media',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
