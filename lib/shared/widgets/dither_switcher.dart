import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/dither_transition.dart';

/// Swaps [child] for a new one cell by cell when its key changes (see
/// [DitherTransition]); at once when animations are off. Use it where the
/// same place starts showing different content, not for every update.
///
/// With [expand], both children fill the box; otherwise they stack from
/// the top-left and the taller one sets the height while they swap.
///
/// With [resize], a change of height is eased too, so what lies below
/// moves instead of jumping: a taller child opens its space while it
/// develops, a shorter one gives the space back once the old child has
/// dissolved. Not for a child whose height changes on its own: the easing
/// would chase it and lag behind; give such a place [collapse].
///
/// With [collapse], only a leaving child's height is eased: it dissolves,
/// then gives its space back. For a place that goes empty.
class DitherSwitcher extends StatelessWidget {
  const DitherSwitcher({
    required this.child,
    this.expand = false,
    this.resize = false,
    this.collapse = false,
    super.key,
  }) : assert(!(resize && collapse), 'collapse eases a part of resize');

  final Widget child;
  final bool expand;
  final bool resize;
  final bool collapse;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : DitherTransition.duration;
    final switcher = AnimatedSwitcher(
      duration: duration,
      reverseDuration: collapse ? duration * 2 : null,
      transitionBuilder: collapse
          ? DitherTransition.collapsingTransition
          : DitherTransition.transition,
      layoutBuilder: expand
          ? DitherTransition.expandedLayout
          : DitherTransition.layout,
      child: child,
    );
    if (!resize) return switcher;
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeInOut,
      alignment: AlignmentDirectional.topStart,
      child: switcher,
    );
  }
}
