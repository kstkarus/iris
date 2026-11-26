import 'package:flutter/widgets.dart';

import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

/// Shared geometry for desktop split screens with a sticky left poster rail
/// beside a scrolling right column (anime details, character, watch sources,
/// and episode picker).
abstract final class DesktopDossierMetrics {
  static const standaloneSplitMinWidth = 1000.0;
  static const splitMinHeight = 500.0;

  /// Left dossier rail width by window size class.
  static double railWidth(WindowSizeClass sizeClass) =>
      sizeClass.isAtLeast(WindowSizeClass.large) ? 296.0 : 240.0;

  /// Horizontal breathing space between the left rail and right content column.
  static double gap(WindowSizeClass sizeClass) =>
      sizeClass.isAtLeast(WindowSizeClass.large) ? 44.0 : 28.0;

  /// Maximum width of tabular list/grid workspaces (sources, torrents,
  /// episodes). Expands on wide desktop / 2K displays (`extraLarge` >= 1600dp).
  static double workspaceMaxWidth(WindowSizeClass sizeClass) =>
      sizeClass.isAtLeast(WindowSizeClass.extraLarge) ? 1120.0 : 920.0;

  /// Whether a standalone sub-page (watch sources / episode picker) uses the
  /// two-column desktop split layout.
  static bool isStandaloneSplit(BuildContext context) {
    final sizeClass = WindowSizeClass.of(context);
    if (!sizeClass.isAtLeast(WindowSizeClass.expanded)) return false;
    final size = MediaQuery.sizeOf(context);
    return size.width >= standaloneSplitMinWidth &&
        size.height >= splitMinHeight;
  }
}
