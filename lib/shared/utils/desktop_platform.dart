import 'package:flutter/foundation.dart';

/// Platforms with a keyboard and a pointer: keyboard shortcuts are worth
/// naming, and menu items that ask for more end in an ellipsis.
bool get isDesktopPlatform => switch (defaultTargetPlatform) {
  TargetPlatform.windows ||
  TargetPlatform.linux ||
  TargetPlatform.macOS => true,
  TargetPlatform.android ||
  TargetPlatform.iOS ||
  TargetPlatform.fuchsia => false,
};

/// [label] marked as asking for more on desktop menus (`Rename…`).
String asksForMore(String label) => isDesktopPlatform ? '$label…' : label;
