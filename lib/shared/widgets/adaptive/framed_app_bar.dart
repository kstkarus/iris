import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

/// A sub-page's bar: the way back and the title sit on the page frame, so
/// the arrow lines up with the content below on any window; the bar's
/// surface and rule still span the window.
class FramedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FramedAppBar({this.title, super.key});

  final Widget? title;

  /// Space between the back button's edge and its glyph: the glyph, not
  /// the button, lines up with the content.
  static const _backGlyphInset = 10.0;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final margin = WindowSizeClass.of(context).pageMargin;
    final canGoBack = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final title = this.title;
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: EdgeInsets.symmetric(horizontal: margin),
        child: MaxWidthBox(
          maxWidth: AdaptiveContentWidth.page,
          alignment: Alignment.center,
          child: Row(
            children: [
              if (canGoBack)
                Transform.translate(
                  offset: const Offset(-_backGlyphInset, 0),
                  child: const BackButton(),
                ),
              if (title != null)
                Expanded(
                  child: Transform.translate(
                    offset: Offset(canGoBack ? -_backGlyphInset + 4 : 0, 0),
                    child: title,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
