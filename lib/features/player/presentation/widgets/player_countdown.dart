import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:iris/shared/utils/motion_duration.dart';

/// Counts down the time an offer or a message over the video has left and
/// calls [onElapsed] when it runs out. A [PlayerCountdownBar] inside [child]
/// draws what is left; while the pointer rests on the bar's plate or the
/// focus is inside it, the bar fills back up and holds full, and the count
/// starts over on leaving. While not [running] (the video paused, loading
/// or not started) it stands where it is and goes on from there.
class PlayerCountdown extends StatefulWidget {
  const PlayerCountdown({
    required this.duration,
    required this.onElapsed,
    required this.child,
    this.running = true,
    this.runningListenable,
    super.key,
  });

  /// How long the bar takes to fill back up under the pointer.
  static const refill = Duration(milliseconds: 250);

  /// Null while nothing counts down: the message waits for the file, or the
  /// offer is pinned or hidden.
  final Duration? duration;
  final VoidCallback onElapsed;
  final Widget child;
  final bool running;

  /// Receives playback changes even while Flutter is between frames.
  final ValueListenable<bool>? runningListenable;

  @override
  State<PlayerCountdown> createState() => _PlayerCountdownState();
}

class _PlayerCountdownState extends State<PlayerCountdown>
    with SingleTickerProviderStateMixin {
  // Preserve: with animations off the OS would run the count 20 times
  // faster, gone before it could be read. The refill follows the setting.
  late final _controller = AnimationController(
    vsync: this,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  )..addListener(_onTick);
  final _holds = <Object>{};
  final _clock = Stopwatch();
  double _remainingAtStart = 1;
  bool get _running => widget.runningListenable?.value ?? widget.running;

  /// Whether this count has run out and said so.
  bool _elapsed = false;

  @override
  void initState() {
    super.initState();
    widget.runningListenable?.addListener(_syncRunning);
    _start(widget.duration);
  }

  @override
  void didUpdateWidget(covariant PlayerCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runningListenable != widget.runningListenable) {
      oldWidget.runningListenable?.removeListener(_syncRunning);
      widget.runningListenable?.addListener(_syncRunning);
    }
    if (widget.duration == null) {
      _clock.stop();
      _controller
        ..stop()
        ..value = 1;
    } else if (oldWidget.duration == null) {
      if (_holds.isEmpty) _start(widget.duration);
    } else {
      _syncRunning();
    }
  }

  @override
  void dispose() {
    widget.runningListenable?.removeListener(_syncRunning);
    _controller.dispose();
    super.dispose();
  }

  void _start(Duration? duration) {
    if (duration == null) return;
    _elapsed = false;
    _controller.value = 1;
    if (_running) _resume();
  }

  void _syncRunning() {
    final duration = widget.duration;
    if (duration == null ||
        _elapsed ||
        _holds.isNotEmpty ||
        _running == _clock.isRunning) {
      return;
    }
    if (_running) {
      _resume();
    } else {
      _clock.stop();
      final remaining =
          _remainingAtStart -
          _clock.elapsedMicroseconds / duration.inMicroseconds;
      _controller
        ..stop()
        ..value = math.min(_controller.value, remaining).clamp(0.0, 1.0);
    }
  }

  /// Goes on from where the count stood, with the time that was left.
  void _resume() {
    final duration = widget.duration;
    if (duration == null || _elapsed || _controller.value <= 0) return;
    _remainingAtStart = _controller.value;
    _clock
      ..reset()
      ..start();
    _controller.animateTo(0, duration: duration * _controller.value);
  }

  // On the frame the bar reaches nothing, not on the one after, when the
  // animation would report itself done.
  void _onTick() {
    if (_elapsed || widget.duration == null || _controller.value > 0) return;
    _elapsed = true;
    _clock.stop();
    widget.onElapsed();
  }

  void _hold(Object reason, bool held) {
    if (!mounted) return;
    if (held) {
      if (_holds.add(reason) && widget.duration != null && !_elapsed) {
        _clock.stop();
        _controller.animateTo(
          1,
          duration: motionDuration(context, PlayerCountdown.refill),
          curve: Curves.easeOut,
        );
      }
    } else if (_holds.remove(reason) && _holds.isEmpty) {
      // From as full as the bar got: all of it after a rest, a little
      // more after a brush past, and never a jump.
      if (_running) _resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CountdownScope(
      remaining: widget.duration == null ? null : _controller,
      hold: _hold,
      child: widget.child,
    );
  }
}

class _CountdownScope extends InheritedWidget {
  const _CountdownScope({
    required this.remaining,
    required this.hold,
    required super.child,
  });

  /// From 1 to 0; null when nothing counts down.
  final Animation<double>? remaining;
  final void Function(Object reason, bool held) hold;

  @override
  bool updateShouldNotify(_CountdownScope oldWidget) =>
      remaining != oldWidget.remaining;
}

/// Lays a thin bar along the bottom of [child], a plate over the video, for
/// the time the enclosing [PlayerCountdown] has left. It shrinks toward the
/// start: when it is gone, the plate goes, and nothing else happens.
///
/// Without a running countdown it is just [child].
class PlayerCountdownBar extends StatelessWidget {
  const PlayerCountdownBar({
    required this.color,
    required this.child,
    this.inset = EdgeInsets.zero,
    super.key,
  });

  static const thickness = 3.0;

  final Color color;

  /// Keeps the bar inside the plate's border.
  final EdgeInsets inset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_CountdownScope>();
    final remaining = scope?.remaining;
    if (scope == null) return child;
    return MouseRegion(
      onEnter: (_) => scope.hold(#pointer, true),
      onExit: (_) => scope.hold(#pointer, false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) => scope.hold(#focus, focused),
        child: Stack(
          children: [
            child,
            if (remaining != null)
              Positioned(
                left: inset.left,
                right: inset.right,
                bottom: inset.bottom,
                height: thickness,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: remaining,
                    builder: (context, _) => FractionallySizedBox(
                      key: const Key('player_countdown_bar'),
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: remaining.value,
                      child: ColoredBox(color: color),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
