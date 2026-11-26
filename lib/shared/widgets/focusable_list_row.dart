import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:iris/shared/utils/motion_duration.dart';

/// A list row with an ink splash that also works from a keyboard: focus
/// shows as an outline, and the Delete key can run [onDelete].
class FocusableListRow extends StatefulWidget {
  const FocusableListRow({
    required this.child,
    this.onDelete,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.focusNode,
    this.filled = false,
    this.inkKey,
    super.key,
  });

  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final FocusNode? focusNode;

  /// Fills the row, e.g. while its menu is open.
  final bool filled;

  /// The ink well's own key, for finding the tap target.
  final Key? inkKey;
  final Widget child;

  @override
  State<FocusableListRow> createState() => _FocusableListRowState();
}

class _FocusableListRowState extends State<FocusableListRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final anim = motionDuration(context, const Duration(milliseconds: 160));
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.delete): ?widget.onDelete,
      },
      child: AnimatedContainer(
        duration: anim,
        curve: Curves.easeOutCubic,
        // Keyboard focus as an outline: a fill this faint would not show.
        foregroundDecoration: BoxDecoration(
          border: _focused
              ? Border.all(color: scheme.onSurface, width: 2)
              : null,
        ),
        child: AnimatedContainer(
          duration: anim,
          curve: Curves.easeOutCubic,
          color: widget.filled ? scheme.surfaceContainer : Colors.transparent,
          child: Material(
            // Ink paints on the nearest Material: this one scrolls with the
            // row, so the list's edge clips the highlight.
            type: MaterialType.transparency,
            child: InkWell(
              key: widget.inkKey,
              mouseCursor:
                  widget.onTap != null ||
                      widget.onLongPress != null ||
                      widget.onSecondaryTap != null
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              // The long-press action supplies its own feedback.
              enableFeedback: widget.onLongPress == null,
              focusNode: widget.focusNode,
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              onSecondaryTap: widget.onSecondaryTap,
              onFocusChange: (focused) => setState(
                () => _focused =
                    focused &&
                    FocusManager.instance.highlightMode ==
                        FocusHighlightMode.traditional,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
