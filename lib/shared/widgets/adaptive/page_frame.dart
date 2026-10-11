import 'package:flutter/widgets.dart';

import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

/// A page body on the frame `FramedAppBar` uses: the window's side margins,
/// a gap above the first row, and at most [AdaptiveContentWidth.page] wide.
class PageFrame extends StatelessWidget {
  /// A top-level page's gap, [WindowSizeClass.pageTop].
  const PageFrame({required this.child, super.key}) : _subPage = false;

  /// The fixed gap under a sub-page's bar.
  const PageFrame.subPage({required this.child, super.key}) : _subPage = true;

  static const _subPageTop = 24.0;

  final Widget child;
  final bool _subPage;

  @override
  Widget build(BuildContext context) {
    final sizeClass = WindowSizeClass.of(context);
    final margin = sizeClass.pageMargin;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        margin,
        _subPage ? _subPageTop : sizeClass.pageTop,
        margin,
        0,
      ),
      child: MaxWidthBox(maxWidth: AdaptiveContentWidth.page, child: child),
    );
  }
}
