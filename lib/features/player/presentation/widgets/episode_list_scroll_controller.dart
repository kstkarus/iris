import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:iris/shared/utils/motion_duration.dart';

/// Reveals a variable-height episode row, even before it has been built.
class EpisodeListScrollController extends ScrollController {
  final targetKey = GlobalKey();
  BuildContext? _sliverContext;
  (int?, int)? _target;
  int _request = 0;

  // A lazy list passes its sliver's context to the item builder.
  void trackItems(BuildContext context) => _sliverContext = context;

  void reveal(
    BuildContext context, {
    required int? fileIndex,
    required int itemIndex,
    double topPadding = 0,
  }) {
    if (_target == (fileIndex, itemIndex)) return;
    _target = (fileIndex, itemIndex);
    final request = ++_request;
    if (itemIndex < 0) return;

    final animate = hasClients;
    const alignment = 0.3;
    double? lower;
    double? upper;

    void afterLayout(Duration _) {
      if (!context.mounted || !hasClients || _request != request) return;
      if (targetKey.currentContext case final target?) {
        Scrollable.ensureVisible(
          target,
          alignment: alignment,
          duration: animate
              ? motionDuration(context, const Duration(milliseconds: 250))
              : Duration.zero,
          curve: Curves.easeOut,
        );
        return;
      }

      final sliverContext = _sliverContext;
      if (sliverContext == null || !sliverContext.mounted) return;
      final sliver = sliverContext.findRenderObject();
      if (sliver is! RenderSliverMultiBoxAdaptor) return;
      final first = sliver.firstChild;
      final last = sliver.lastChild;
      if (first == null || last == null) return;

      final firstIndex = sliver.indexOf(first);
      final lastIndex = sliver.indexOf(last);
      final start = sliver.childScrollOffset(first)!;
      final end = sliver.childScrollOffset(last)! + last.size.height;
      final extent = (end - start) / (lastIndex - firstIndex + 1);
      final pixels = position.pixels;
      if (itemIndex < firstIndex) {
        upper = pixels;
      } else if (itemIndex > lastIndex) {
        lower = pixels;
      } else {
        return;
      }

      var offset =
          topPadding +
          start +
          (itemIndex - firstIndex) * extent -
          alignment * position.viewportDimension;
      // Different row heights can make the estimate overshoot in either
      // direction. Narrow the search between offsets already visited.
      if (lower != null &&
          upper != null &&
          (offset <= lower! || offset >= upper!)) {
        offset = (lower! + upper!) / 2;
      }
      final next = offset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (next == pixels) return;
      jumpTo(next);
      WidgetsBinding.instance.addPostFrameCallback(afterLayout);
    }

    WidgetsBinding.instance.addPostFrameCallback(afterLayout);
  }
}
