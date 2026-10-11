import 'package:flutter/material.dart';

import 'package:iris/features/player/presentation/widgets/player_popover.dart';

/// The frame of a player panel (sheet, dialog or popover): [title] above
/// [child], scrolling within [maxHeightFactor] of the window's height.
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({
    required this.title,
    required this.child,
    this.maxHeightFactor = 0.85,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    super.key,
  });

  final String title;
  final Widget child;
  final double maxHeightFactor;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * maxHeightFactor,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + mediaQuery.viewInsets.bottom,
          ),
          child: Material(
            // Ink paints on the nearest Material: this one scrolls with the list,
            // so the sheet's edge clips the highlight.
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: crossAxisAlignment,
              mainAxisSize: MainAxisSize.min,
              children: [
                // A popover's button already names it.
                if (!isInPlayerPopover(context)) ...[
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
