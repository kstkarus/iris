import 'package:flutter/material.dart';

import 'package:iris/shared/haptics/app_haptics.dart';
import 'package:iris/shared/utils/bayer_mask.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_transition.dart';

/// One of a row of text tabs, the app's sections or a page's views: the
/// current one is marked with a square, not boxed, so the tabs stay as
/// quiet as the text around them.
class MarkedTab extends StatelessWidget {
  const MarkedTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectionFeedback = true,
    super.key,
  });

  static const _markerDuration = Duration(milliseconds: 220);

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool selectionFeedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final anim = motionDuration(context, _markerDuration);
    final mark = ColoredBox(color: scheme.onSurface);
    final labelStyle = (theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(
          fontFamily: DetailLayout.sansFont,
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
        );
    final marker = SizedBox.square(
      dimension: 6,
      child: anim == Duration.zero
          ? (selected ? mark : null)
          : TweenAnimationBuilder<int>(
              tween: IntTween(end: selected ? BayerMask.steps : 0),
              duration: anim,
              curve: Curves.easeOutCubic,
              child: mark,
              builder: (_, open, child) =>
                  BayerMasked(open: open, cell: 1, child: child),
            ),
    );
    final styledLabel = anim == Duration.zero
        ? DefaultTextStyle(style: labelStyle, child: Text(label))
        : AnimatedDefaultTextStyle(
            duration: anim,
            curve: Curves.easeOutCubic,
            style: labelStyle,
            child: Text(label),
          );
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () {
          if (!selected && selectionFeedback) AppHaptics.selection();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [marker, const SizedBox(width: 8), styledLabel],
            ),
          ),
        ),
      ),
    );
  }
}
