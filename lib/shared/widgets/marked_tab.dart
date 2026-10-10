import 'package:flutter/material.dart';

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
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : _markerDuration,
                width: 6,
                height: 6,
                color: selected ? scheme.onSurface : Colors.transparent,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
