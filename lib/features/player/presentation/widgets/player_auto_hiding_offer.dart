import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:iris/features/player/presentation/widgets/player_countdown.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/active_layer.dart';
import 'package:iris/shared/widgets/dither_transition.dart';

/// Shows [child] for [shownAtStart] when it appears, counting down, and
/// from then on exactly while the player's controls are visible, without a
/// countdown; [pinned] keeps it shown.
///
/// A [PlayerCountdownBar] in [child] shows the time left at the start;
/// resting the pointer on it, or the focus inside it, holds it. The time
/// passes only while [running] (the video moving), when given.
class PlayerAutoHidingOffer extends StatefulWidget {
  const PlayerAutoHidingOffer({
    required this.controlsVisible,
    required this.child,
    this.pinned = false,
    this.running,
    super.key,
  });

  static const shownAtStart = Duration(seconds: 8);

  final ValueListenable<bool> controlsVisible;
  final bool pinned;
  final ValueListenable<bool>? running;
  final Widget child;

  @override
  State<PlayerAutoHidingOffer> createState() => _PlayerAutoHidingOfferState();
}

class _PlayerAutoHidingOfferState extends State<PlayerAutoHidingOffer> {
  /// The first showing, on its own; after it the offer goes with the
  /// controls.
  bool _intro = true;

  void _endIntro() {
    if (mounted) setState(() => _intro = false);
  }

  @override
  Widget build(BuildContext context) {
    final pinned = widget.pinned;
    return PlayerCountdown(
      duration: _intro && !pinned ? PlayerAutoHidingOffer.shownAtStart : null,
      onElapsed: _endIntro,
      runningListenable: widget.running,
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.controlsVisible,
        builder: (context, controlsVisible, child) {
          final visible = pinned || _intro || controlsVisible;
          return ActiveLayer(
            active: visible,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: motionDuration(
                context,
                const Duration(milliseconds: 200),
              ),
              child: child,
            ),
          );
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: motionDuration(context, const Duration(milliseconds: 300)),
          builder: (context, value, child) => DitherTransition.transition(
            child!,
            AlwaysStoppedAnimation(value),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
