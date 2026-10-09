import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:iris/features/player/presentation/widgets/player_popover.dart';

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

/// Wide windows and desktop platforms show player panels as popovers or
/// dialogs.
bool usesPlayerDialogPresentation(BuildContext context) {
  return isDesktopPlayerPlatform() ||
      isPlayerWideWidth(MediaQuery.sizeOf(context).width);
}

/// Shows player settings panels as a modal bottom sheet on compact windows.
/// On wide windows or desktop they open as a popover of [anchor], the
/// button that opened them, [popoverWidth] wide; without an anchor, as a
/// centred, width-constrained dialog.
///
/// [barrierColor] dims what is behind a sheet or a dialog; the default is
/// the usual modal dim. A popover leaves the video undimmed.
Future<T?> showPlayerAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  BuildContext? anchor,
  double popoverWidth = playerDialogMaxWidth,
  String? semanticsLabel,
  bool isScrollControlled = false,
  Color? barrierColor,
}) {
  if (usesPlayerDialogPresentation(context)) {
    if (anchor != null && anchor.mounted) {
      return showPlayerPopover<T>(
        anchor: anchor,
        width: popoverWidth,
        semanticsLabel: semanticsLabel,
        builder: builder,
      );
    }
    return showDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierColor: barrierColor,
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
    barrierColor: barrierColor,
    builder: builder,
  );
}
