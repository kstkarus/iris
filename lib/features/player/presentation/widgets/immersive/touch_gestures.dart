part of '../player_immersive_controls.dart';

/// The side of the video a double tap seeks to.
enum _SeekSide { backward, forward }

/// Taps in a row on one side: the first two seek a step, each one after
/// adds a step, all counted from where the row started rather than from a
/// position the player may not have caught up with.
class _SeekStreak {
  const _SeekStreak({
    required this.side,
    required this.anchor,
    this.total = Duration.zero,
  });

  final _SeekSide side;
  final Duration anchor;
  final Duration total;

  Duration get target =>
      side == _SeekSide.forward ? anchor + total : anchor - total;

  _SeekStreak extended() => _SeekStreak(
    side: side,
    anchor: anchor,
    total: total + PlayerImmersiveControls.seekStep,
  );
}

/// The video's gestures by touch: a tap shows or hides the controls, a
/// double tap on either side seeks ±10 s (more taps add more), a long
/// press plays at 2× while held, and a pinch fills the screen with the
/// video or fits it back. A tap in the middle answers at once; on the
/// sides it waits a moment for a second one. Touches that start where the
/// system takes its own gestures (the edges) are left to it.
class _TouchGestures extends StatefulWidget {
  const _TouchGestures({
    required this.enabled,
    required this.playing,
    required this.position,
    required this.duration,
    required this.onTap,
    required this.onSeek,
    required this.onFastForward,
    required this.videoFit,
  });

  /// The width of each side's zone, as a share of the video's.
  static const sideZone = 0.35;

  /// How long after a tap the next one still adds to its row.
  static const streakWindow = Duration(milliseconds: 700);

  /// A pinch this far apart fills the screen; this close, fits it back.
  static const zoomIn = 1.15;
  static const zoomOut = 0.87;

  static const _fitPlateDuration = Duration(milliseconds: 900);

  /// Off while the screen is locked.
  final bool enabled;

  /// A long press plays faster only while the video plays.
  final bool playing;
  final ValueGetter<Duration> position;
  final ValueGetter<Duration> duration;
  final VoidCallback onTap;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<bool> onFastForward;

  /// What a pinch sets; null takes no pinch.
  final ValueNotifier<BoxFit>? videoFit;

  @override
  State<_TouchGestures> createState() => _TouchGesturesState();
}

class _TouchGesturesState extends State<_TouchGestures> {
  /// A side tap waiting to see whether a second one follows.
  Timer? _pendingTap;
  _SeekSide? _pendingSide;
  Offset? _pendingPosition;

  _SeekStreak? _streak;
  Timer? _streakTimer;

  bool _tapIgnored = false;
  bool _fastForward = false;

  bool _scaleIgnored = false;

  /// A pinch decides once, however far it goes on.
  bool _scaleDecided = false;
  BoxFit? _fitPlate;
  Timer? _fitPlateTimer;

  @override
  void didUpdateWidget(covariant _TouchGestures oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _cancelPending();
      _streakTimer?.cancel();
      _streak = null;
      if (_fastForward) {
        _fastForward = false;
        widget.onFastForward(false);
      }
    }
  }

  @override
  void dispose() {
    _pendingTap?.cancel();
    _streakTimer?.cancel();
    _fitPlateTimer?.cancel();
    if (_fastForward) widget.onFastForward(false);
    super.dispose();
  }

  /// Where the system's own edge gestures (back, the bars) begin.
  bool _inSystemGestureArea(Offset global) {
    final insets = MediaQuery.systemGestureInsetsOf(context);
    final size = MediaQuery.sizeOf(context);
    return global.dx < insets.left ||
        global.dx > size.width - insets.right ||
        global.dy < insets.top ||
        global.dy > size.height - insets.bottom;
  }

  _SeekSide? _sideOf(Offset local) {
    final width = context.size?.width ?? 0;
    if (width <= 0) return null;
    final share = local.dx / width;
    if (share < _TouchGestures.sideZone) return _SeekSide.backward;
    if (share > 1 - _TouchGestures.sideZone) return _SeekSide.forward;
    return null;
  }

  void _onTapDown(TapDownDetails details) {
    _tapIgnored = _inSystemGestureArea(details.globalPosition);
  }

  void _onTapUp(TapUpDetails details) {
    if (_tapIgnored || !widget.enabled) return;
    final local = details.localPosition;
    final side = _sideOf(local);
    final streak = _streak;
    if (side == null) {
      _cancelPending();
      _endStreak();
      widget.onTap();
      return;
    }
    if (streak != null) {
      // In a row every tap counts at once; the other side turns it round
      // from where it got to.
      _seek(
        streak.side == side
            ? streak.extended()
            : _SeekStreak(side: side, anchor: streak.target).extended(),
      );
      return;
    }
    final pendingPosition = _pendingPosition;
    if (_pendingSide == side &&
        pendingPosition != null &&
        (pendingPosition - local).distance <= kDoubleTapSlop) {
      _cancelPending();
      _seek(_SeekStreak(side: side, anchor: widget.position()).extended());
      return;
    }
    _cancelPending();
    _pendingSide = side;
    _pendingPosition = local;
    _pendingTap = Timer(kDoubleTapTimeout, () {
      _pendingTap = null;
      _pendingSide = null;
      _pendingPosition = null;
      if (mounted) widget.onTap();
    });
  }

  void _cancelPending() {
    _pendingTap?.cancel();
    _pendingTap = null;
    _pendingSide = null;
    _pendingPosition = null;
  }

  void _seek(_SeekStreak streak) {
    setState(() => _streak = streak);
    var target = streak.target;
    final duration = widget.duration();
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    widget.onSeek(target);
    _streakTimer?.cancel();
    _streakTimer = Timer(_TouchGestures.streakWindow, _endStreak);
  }

  void _endStreak() {
    _streakTimer?.cancel();
    _streakTimer = null;
    if (mounted && _streak != null) setState(() => _streak = null);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (!widget.enabled ||
        !widget.playing ||
        _inSystemGestureArea(details.globalPosition)) {
      return;
    }
    _cancelPending();
    _setFastForward(true);
  }

  void _onLongPressEnd(LongPressEndDetails details) => _releaseFastForward();

  void _releaseFastForward() => _setFastForward(false);

  void _setFastForward(bool held) {
    if (held == _fastForward) return;
    setState(() => _fastForward = held);
    widget.onFastForward(held);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _scaleIgnored = _inSystemGestureArea(details.focalPoint);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_scaleIgnored ||
        _scaleDecided ||
        !widget.enabled ||
        details.pointerCount < 2) {
      return;
    }
    if (details.scale > _TouchGestures.zoomIn) {
      _setFit(BoxFit.cover);
    } else if (details.scale < _TouchGestures.zoomOut) {
      _setFit(BoxFit.contain);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // A finger left: the next pinch decides anew.
    if (details.pointerCount < 2) _scaleDecided = false;
  }

  void _setFit(BoxFit fit) {
    _scaleDecided = true;
    final videoFit = widget.videoFit;
    if (videoFit == null) return;
    videoFit.value = fit;
    _fitPlateTimer?.cancel();
    setState(() => _fitPlate = fit);
    _fitPlateTimer = Timer(_TouchGestures._fitPlateDuration, () {
      if (mounted) setState(() => _fitPlate = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final streak = _streak;
    final fitPlate = _fitPlate;
    return Stack(
      fit: StackFit.expand,
      children: [
        RawGestureDetector(
          key: const Key('player_immersive_tap_layer'),
          behavior: HitTestBehavior.opaque,
          gestures: {
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(debugOwner: this),
                  (recognizer) => recognizer
                    ..onTapDown = _onTapDown
                    ..onTapUp = _onTapUp,
                ),
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer
                >(
                  () => LongPressGestureRecognizer(debugOwner: this),
                  (recognizer) => recognizer
                    ..onLongPressStart = _onLongPressStart
                    ..onLongPressEnd = _onLongPressEnd
                    ..onLongPressCancel = _releaseFastForward,
                ),
            ScaleGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
                  () => ScaleGestureRecognizer(debugOwner: this),
                  (recognizer) => recognizer
                    ..onStart = _onScaleStart
                    ..onUpdate = _onScaleUpdate
                    ..onEnd = _onScaleEnd,
                ),
          },
        ),
        if (streak != null)
          _HudPlate(
            key: const Key('player_seek_streak_plate'),
            alignment: Alignment(
              streak.side == _SeekSide.forward ? 0.6 : -0.6,
              0,
            ),
            child: Text(
              streak.side == _SeekSide.forward
                  ? '+${streak.total.inSeconds}'
                  : '−${streak.total.inSeconds}',
            ),
          ),
        if (_fastForward)
          _HudPlate(
            key: const Key('player_fast_forward_plate'),
            child: Text(
              l10n.playerPlaybackRate(MediaKitPlayerEngine.fastForwardRate),
            ),
          )
        else if (fitPlate != null)
          _HudPlate(
            key: const Key('player_fit_plate'),
            child: Text(
              fitPlate == BoxFit.cover
                  ? l10n.playerZoomFill
                  : l10n.playerZoomFit,
            ),
          ),
      ],
    );
  }
}
