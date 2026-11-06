import 'package:flutter/material.dart';

import 'package:iris/shared/theme/inverse_theme.dart';

/// App dialogs use the same inverse theme as adaptive sheets.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final theme = InverseTheme.of(Theme.of(context));
  return showDialog<T>(
    context: context,
    builder: (_) => Theme(
      data: theme,
      child: Builder(builder: builder),
    ),
  );
}
