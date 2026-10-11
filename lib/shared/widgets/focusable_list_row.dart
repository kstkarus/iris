import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A list row with an ink splash that also works from a keyboard: focus
/// shows as an outline, and the Delete key runs [onDelete].
class FocusableListRow extends StatefulWidget {
  const FocusableListRow({
    required this.onDelete,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.filled = false,
    this.inkKey,
    super.key,
  });

  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

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
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.delete): widget.onDelete,
      },
      child: DecoratedBox(
        // Keyboard focus as an outline: a fill this faint would not show.
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: _focused
              ? Border.all(color: scheme.onSurface, width: 2)
              : null,
        ),
        child: Material(
          // Ink paints on the nearest Material: this one scrolls with the
          // row, so the list's edge clips the highlight.
          color: widget.filled ? scheme.surfaceContainer : Colors.transparent,
          child: InkWell(
            key: widget.inkKey,
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
    );
  }
}
