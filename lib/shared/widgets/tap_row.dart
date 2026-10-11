import 'package:flutter/material.dart';

/// A row of a list that reacts to a tap with an ink splash.
class TapRow extends StatelessWidget {
  const TapRow({
    required this.onTap,
    required this.child,
    this.inkKey,
    super.key,
  });

  final VoidCallback? onTap;
  final Widget child;

  /// The ink well's own key, for finding the tap target.
  final Key? inkKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      // Ink paints on the nearest Material: this one scrolls with the row,
      // so the list's edge clips the highlight.
      type: MaterialType.transparency,
      child: InkWell(key: inkKey, onTap: onTap, child: child),
    );
  }
}
