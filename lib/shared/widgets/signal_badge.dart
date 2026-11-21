import 'package:flutter/material.dart';

import 'package:iris/shared/utils/bayer_mask.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/dither_transition.dart';

/// Places a quiet square signal dot in the top-end corner of [child] without
/// altering [child]'s layout size or shifting surrounding elements.
class SignalBadge extends StatelessWidget {
  const SignalBadge({
    required this.visible,
    required this.child,
    this.size = 5,
    this.top = 0,
    this.end = -8,
    this.cutout = false,
    this.color,
    this.dotKey,
    super.key,
  });

  static const _duration = Duration(milliseconds: 220);
  static const _cutoutWidth = 1.5;

  final bool visible;
  final Widget child;
  final double size;
  final double top;
  final double end;

  /// Draws a surface-coloured border around the square so it separates cleanly
  /// from an underlying pixel icon.
  final bool cutout;
  final Color? color;
  final Key? dotKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final anim = motionDuration(context, _duration);
    final dotColor = color ?? scheme.tertiary;
    final Widget square = cutout
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: dotColor,
              border: Border.all(
                color: scheme.surface,
                width: _cutoutWidth,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
          )
        : ColoredBox(color: dotColor);
    final dot = SizedBox.square(
      key: visible ? dotKey : null,
      dimension: size,
      child: anim == Duration.zero
          ? (visible ? square : null)
          : TweenAnimationBuilder<int>(
              tween: IntTween(end: visible ? BayerMask.steps : 0),
              duration: anim,
              curve: Curves.easeOutCubic,
              child: square,
              builder: (_, open, child) =>
                  BayerMasked(open: open, cell: 1, child: child),
            ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        PositionedDirectional(
          top: top,
          end: end,
          child: IgnorePointer(child: ExcludeSemantics(child: dot)),
        ),
      ],
    );
  }
}
