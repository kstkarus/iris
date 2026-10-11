import 'package:flutter/widgets.dart';

/// Scrolls the widget of [key] into view once this frame is laid out, a
/// little above the middle, so the rows around it show too.
void revealAfterLayout(GlobalKey key, {Duration duration = Duration.zero}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = key.currentContext;
    if (context == null || !context.mounted) return;
    Scrollable.ensureVisible(context, alignment: 0.3, duration: duration);
  });
}
