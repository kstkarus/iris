import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

/// Shows [builder] as a modal bottom sheet on compact windows and as a
/// centered dialog on medium and wider windows, as recommended by Material 3.
///
/// The content should size itself with `MainAxisSize.min` and put scrollable
/// parts into a `Flexible`, because the available height is only capped, not
/// forced.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  if (WindowSizeClass.of(context).isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9,
          ),
          child: builder(sheetContext),
        );
      },
    );
  }

  return showDialog<T>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AdaptiveContentWidth.form,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.85,
          ),
          child: builder(dialogContext),
        ),
      );
    },
  );
}
