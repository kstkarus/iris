import 'package:flutter/material.dart';

/// Counts down the time an offer or a message over the video has left and
/// calls [onElapsed] when it runs out. A [PlayerCountdownBar] inside [child]
/// draws what is left; while the pointer rests on the bar's plate or the
/// focus is inside it, the countdown holds full and starts again on leaving.
class PlayerCountdown extends StatefulWidget {
  const PlayerCountdown({
    required this.duration,
    required this.onElapsed,
    required this.child,
    this.afterHold,
    this.generation = 0,
    super.key,
  });

  /// Null while nothing counts down: the message waits for the file, or the
  /// offer is pinned or hidden.
  final Duration? duration;

  /// What is left after a hold ends; [duration] by default.
  final Duration? afterHold;

  /// A new value starts the count again from full.
  final int generation;
  final VoidCallback onElapsed;
  final Widget child;

  @override
  State<PlayerCountdown> createState() => _PlayerCountdownState();
}

class _PlayerCountdownState extends State<PlayerCountdown>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, value: 1)
    ..addListener(_onTick);
  final _holds = <Object>{};

  /// Whether this count has run out and said so.
  bool _elapsed = false;

  @override
  void initState() {
    super.initState();
    _start(widget.duration);
  }

  @override
  void didUpdateWidget(covariant PlayerCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration == null) {
      _controller
        ..stop()
        ..value = 1;
    } else if (oldWidget.duration == null ||
        widget.generation != oldWidget.generation) {
      if (_holds.isEmpty) _start(widget.duration);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start(Duration? duration) {
    if (duration == null) return;
    _elapsed = false;
    _controller
      ..value = 1
      ..animateTo(0, duration: duration);
  }

  // On the frame the bar reaches nothing, not on the one after, when the
  // animation would report itself done.
  void _onTick() {
    if (_elapsed || widget.duration == null || _controller.value > 0) return;
    _elapsed = true;
    widget.onElapsed();
  }

  void _hold(Object reason, bool held) {
    if (!mounted) return;
    if (held) {
      if (_holds.add(reason) && widget.duration != null) {
        _controller
          ..stop()
          ..value = 1;
      }
    } else if (_holds.remove(reason) && _holds.isEmpty) {
      _start(widget.afterHold ?? widget.duration);
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
