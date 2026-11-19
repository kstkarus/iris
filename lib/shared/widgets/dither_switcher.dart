import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/dither_transition.dart';

/// Swaps [child] for a new one cell by cell when its key changes (see
/// [DitherTransition]); at once when animations are off. Use it where the
/// same place starts showing different content, not for every update.
///
/// With [expand], both children fill the box; otherwise they stack from
/// the top-left and the taller one sets the height while they swap.
///
/// With [collapse], a leaving child's height is eased: it dissolves, then
/// gives its space back, so what lies below slides instead of jumping.
/// For a place that goes empty.
///
/// [resizeDuration] also eases changes in the size of the stack, keeping
/// its children anchored to [alignment].
class DitherSwitcher extends StatelessWidget {
  const DitherSwitcher({
    required this.child,
    this.expand = false,
    this.collapse = false,
    this.duration = DitherTransition.duration,
    this.reverseDuration,
    this.resizeDuration = Duration.zero,
    this.alignment = AlignmentDirectional.topStart,
    super.key,
  });

  final Widget child;
  final bool expand;
  final bool collapse;

  /// How long a swap takes; shorter where it answers a gesture.
  final Duration duration;

  /// Overrides removal without changing how new content appears.
  final Duration? reverseDuration;
  final Duration resizeDuration;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final switcher = AnimatedSwitcher(
      duration: reducedMotion ? Duration.zero : duration,
      reverseDuration: reducedMotion
          ? Duration.zero
          : reverseDuration ?? (collapse ? duration * 2 : null),
      transitionBuilder: collapse
          ? DitherTransition.collapsingTransition
          : DitherTransition.transition,
      layoutBuilder: expand
          ? DitherTransition.expandedLayout
          : (current, previous) => DitherTransition.layout(
              current,
              previous,
              alignment: alignment,
            ),
      child: child,
    );
    if (reducedMotion || resizeDuration == Duration.zero) return switcher;
    return AnimatedSize(
      duration: resizeDuration,
      curve: Curves.easeOutCubic,
      alignment: alignment,
      child: switcher,
    );
  }
}
