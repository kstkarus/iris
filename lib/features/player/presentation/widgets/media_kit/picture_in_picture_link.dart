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
    ];
    unawaited(
      _window.isSupported().then((supported) {
        if (_disposed || !supported) return;
        this.supported = true;
        onSupported();
      }),
    );
    follow();
  }

  final PictureInPicture _window;
  MediaKitPlayerEngine _engine;
  late final List<StreamSubscription<void>> _subscriptions;

  /// The player whose streams are followed; a new one comes with changed
  /// decoding preferences.
  Player? _player;
  List<StreamSubscription<Object?>> _playerSubscriptions = const [];
  bool _disposed = false;

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

  Future<bool> enter() => _window.enter();

  /// Follows the engine's current player, if it changed.
  void follow() {
    final player = _engine.hasPlayer ? _engine.player : null;
    if (identical(player, _player)) return;
    _player = player;
    for (final subscription in _playerSubscriptions) {
      unawaited(subscription.cancel());
    }
    _playerSubscriptions = player == null
        ? const []
        : [
            player.stream.playing.listen((_) => _report()),
            player.stream.width.listen((_) => _report()),
            player.stream.height.listen((_) => _report()),
          ];
    _report();
  }

  void _report() {
    final player = _player;
    if (_disposed || player == null) return;
    final state = player.state;
    final width = state.width;
    final height = state.height;
    unawaited(
      _window.setPlayer(
        playing: state.playing,
        aspectRatio: width != null && height != null && width > 0 && height > 0
            ? width / height
            : null,
        playLabel: _labels.play,
        pauseLabel: _labels.pause,
      ),
    );
  }

  void _playOrPause() {
    if (_engine.hasPlayer) unawaited(_engine.player.playOrPause());
  }

  void _pause() {
    if (_engine.hasPlayer) unawaited(_engine.player.pause());
  }

  void dispose() {
    _disposed = true;
    for (final subscription in [..._subscriptions, ..._playerSubscriptions]) {
      unawaited(subscription.cancel());
    }
    unawaited(_window.clearPlayer());
  }
}
