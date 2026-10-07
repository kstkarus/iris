import 'package:flutter/widgets.dart';

/// Maximum content widths that keep lines and controls readable on wide
/// windows.
abstract final class AdaptiveContentWidth {
  /// Search fields, dialogs and other single-control surfaces.
  static const double form = 560;

  /// Long-form text such as descriptions.
  static const double reading = 720;

  /// Single-column lists of cards.
  static const double list = 840;

  /// Pages opened from a section (an anime, its releases, a torrent's
  /// files): no navigation beside them, so their rows stay this wide.
  static const double subpage = 1200;

  /// Multi-pane pages and grids.
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
