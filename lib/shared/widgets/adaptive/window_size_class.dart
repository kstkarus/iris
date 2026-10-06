import 'package:flutter/widgets.dart';

/// Material 3 window size classes, derived from the available width.
///
/// Breakpoints follow https://m3.material.io/foundations/layout/applying-layout.
enum WindowSizeClass {
  /// Phones in portrait: width < 600.
  compact,

  /// Tablets in portrait, foldables: 600 <= width < 840.
  medium,

  /// Tablets in landscape, small desktop windows: 840 <= width < 1200.
  expanded,

  /// Desktop windows: 1200 <= width < 1600.
  large,

  /// Wide desktop windows: width >= 1600.
  extraLarge;

  static const double mediumMinWidth = 600;
  static const double expandedMinWidth = 840;
  static const double largeMinWidth = 1200;
  static const double extraLargeMinWidth = 1600;

  static WindowSizeClass fromWidth(double width) {
    if (width >= extraLargeMinWidth) {
      return WindowSizeClass.extraLarge;
    }
    if (width >= largeMinWidth) {
      return WindowSizeClass.large;
    }
    if (width >= expandedMinWidth) {
      return WindowSizeClass.expanded;
    }
    if (width >= mediumMinWidth) {
      return WindowSizeClass.medium;
    }
    return WindowSizeClass.compact;
  }

  /// Size class of the whole window. Use for screen-level decisions such as
  /// navigation; prefer [fromWidth] with `LayoutBuilder` for components.
  static WindowSizeClass of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  bool get isCompact => this == WindowSizeClass.compact;

  bool isAtLeast(WindowSizeClass other) => index >= other.index;

  /// Horizontal page margin recommended by Material 3 for this size class.
  double get pageMargin => isCompact ? 16 : 24;
}
