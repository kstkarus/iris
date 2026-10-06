import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Material 3 "medium" window class lower bound.
const playerWideLayoutMinWidth = 600.0;

/// Maximum width of player dialogs on wide windows (M3 basic dialog).
const playerDialogMaxWidth = 560.0;

bool isDesktopPlayerPlatform([TargetPlatform? platform]) {
  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS => true,
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => false,
  };
}

bool isPlayerWideWidth(double width) => width >= playerWideLayoutMinWidth;

/// Wide windows and desktop platforms show player panels as dialogs.
bool usesPlayerDialogPresentation(BuildContext context) {
  return isDesktopPlayerPlatform() ||
      isPlayerWideWidth(MediaQuery.sizeOf(context).width);
}

/// Shows player settings panels as a modal bottom sheet on compact windows and
/// as a centered, width-constrained dialog on wide windows or desktop.
Future<T?> showPlayerAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  if (usesPlayerDialogPresentation(context)) {
    return showDialog<T>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => Dialog(
        key: const Key('player_adaptive_sheet_dialog'),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: playerDialogMaxWidth),
          child: builder(dialogContext),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: isScrollControlled,
    builder: builder,
  );
}
