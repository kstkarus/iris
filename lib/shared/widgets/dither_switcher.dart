import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/dither_transition.dart';

/// Swaps [child] for a new one cell by cell when its key changes (see
/// [DitherTransition]); at once when animations are off. Use it where the
/// same place starts showing different content, not for every update.
///
/// With [expand], both children fill the box; otherwise they stack from
/// the top-left and the taller one sets the height while they swap.
class DitherSwitcher extends StatelessWidget {
  const DitherSwitcher({required this.child, this.expand = false, super.key});

  final Widget child;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : DitherTransition.duration,
      transitionBuilder: DitherTransition.transition,
      layoutBuilder: expand
          ? DitherTransition.expandedLayout
          : DitherTransition.layout,
      child: child,
    );
  }
}
