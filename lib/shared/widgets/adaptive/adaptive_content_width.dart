import 'package:flutter/widgets.dart';

/// Maximum content widths that keep lines and controls readable on wide
/// windows.
abstract final class AdaptiveContentWidth {
  /// Search fields, dialogs and other single-control surfaces.
  static const double form = 560;

  /// Long-form text such as descriptions.
  static const double reading = 720;

  /// The frame every page shares, the top bar and sub-page bars included:
  /// centred, with the content left-aligned inside, so the left edge stays
  /// put when moving between pages.
  static const double page = 1600;
}

/// Centers [child] horizontally and caps its width at [maxWidth].
class MaxWidthBox extends StatelessWidget {
  const MaxWidthBox({
    required this.maxWidth,
    required this.child,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final double maxWidth;
  final AlignmentGeometry alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
