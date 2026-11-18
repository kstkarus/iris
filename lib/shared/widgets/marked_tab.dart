import 'package:flutter/material.dart';

import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/detail_layout.dart';

/// One of a row of text tabs, the app's sections or a page's views: the
/// current one is marked with a square, not boxed, so the tabs stay as
/// quiet as the text around them.
class MarkedTab extends StatelessWidget {
  const MarkedTab({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  static const _markerDuration = Duration(milliseconds: 220);

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final anim = motionDuration(context, _markerDuration);
    final markerColor = selected ? scheme.onSurface : Colors.transparent;
    final labelStyle = (theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(
          fontFamily: DetailLayout.sansFont,
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
        );
    final marker = anim == Duration.zero
        ? Container(width: 6, height: 6, color: markerColor)
        : AnimatedContainer(
            duration: anim,
            curve: Curves.easeOutCubic,
            width: 6,
            height: 6,
            color: markerColor,
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
        onTap: onTap,
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
