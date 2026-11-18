import 'package:flutter/material.dart';

import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/tap_row.dart';

/// A square check box with its label, for both single choice ([exclusive])
/// and multiple choice lists, so every option list reads the same.
class OptionToggle extends StatelessWidget {
  const OptionToggle({
    required this.label,
    required this.selected,
    required this.onChanged,
    this.exclusive = false,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  /// One of a group where exactly one is selected.
  final bool exclusive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final anim = motionDuration(context, const Duration(milliseconds: 160));
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: exclusive,
      child: TapRow(
        onTap: () => onChanged(exclusive || !selected),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: anim,
                  curve: Curves.easeOutCubic,
                  width: 18,
                  height: 18,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                      width: 1.5,
                    ),
                  ),
                  child: AnimatedContainer(
                    duration: anim,
                    curve: Curves.easeOutCubic,
                    color: selected ? scheme.onSurface : Colors.transparent,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: anim,
                    curve: Curves.easeOutCubic,
                    style: (theme.textTheme.bodyMedium ?? const TextStyle())
                        .copyWith(
                          fontFamily: DetailLayout.sansFont,
                          fontSize: 15,
                          fontWeight: selected
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: selected
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                    child: Text(label),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
