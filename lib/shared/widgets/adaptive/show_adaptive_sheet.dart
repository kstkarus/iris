import 'package:flutter/material.dart';

import 'package:iris/shared/theme/inverse_theme.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

/// Shows [builder] as a modal bottom sheet on compact windows and as a
/// centered dialog on medium and wider windows, as recommended by Material 3.
///
/// Both open in reverse, in the [InverseTheme]: an overlay reads as a
/// separate sheet laid over the page rather than more of the page. Both
/// cover the whole window, the app's navigation included, so nothing
/// behind a modal looks usable; the content gets what it needs from its
/// opener's arguments, not from providers around the page.
///
/// The content should size itself with `MainAxisSize.min` and put scrollable
/// parts into a `Flexible`, because the available height is only capped, not
/// forced.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final inverse = InverseTheme.of(Theme.of(context));
  if (WindowSizeClass.of(context).isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: inverse.bottomSheetTheme.modalBackgroundColor,
      builder: (sheetContext) {
        return Theme(
          data: inverse,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9,
            ),
            child: Builder(builder: builder),
          ),
        );
      },
    );
  }

  return showDialog<T>(
    context: context,
    builder: (dialogContext) {
      return Theme(
        data: inverse,
        child: Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AdaptiveContentWidth.form,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.85,
            ),
            child: Builder(builder: builder),
          ),
        ),
      );
    },
  );
}
