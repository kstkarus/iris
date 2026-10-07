import 'package:flutter/material.dart';

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
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: exclusive,
      child: Material(
        // Ink paints on the nearest Material: this one scrolls with the row,
        // so the list's edge clips the highlight.
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => onChanged(exclusive || !selected),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
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
                    child: selected
                        ? ColoredBox(color: scheme.onSurface)
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: selected
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
