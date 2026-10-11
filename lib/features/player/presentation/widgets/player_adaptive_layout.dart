import 'package:flutter/material.dart';

import 'package:iris/features/player/presentation/widgets/player_popover.dart';
import 'package:iris/shared/utils/desktop_platform.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

/// Wide windows and desktop platforms show player panels as popovers or
/// dialogs.
bool _usesDialogPresentation(BuildContext context) {
  return isDesktopPlatform || !WindowSizeClass.of(context).isCompact;
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
  double popoverWidth = AdaptiveContentWidth.form,
  String? semanticsLabel,
  bool isScrollControlled = false,
  Color? barrierColor,
}) {
  if (_usesDialogPresentation(context)) {
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
          constraints: const BoxConstraints(
            maxWidth: AdaptiveContentWidth.form,
          ),
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
