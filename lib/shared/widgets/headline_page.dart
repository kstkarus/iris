import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/headline_anchor.dart';
import 'package:iris/shared/widgets/page_title.dart';

/// A page whose [body] heads itself with its name in a [HeadlineAnchor],
/// so the bar only navigates back until the name scrolls under it; then
/// the bar shows [title].
class HeadlinePage extends StatefulWidget {
  const HeadlinePage({required this.title, required this.body, super.key});

  /// Empty while the name is not known.
  final String title;
  final Widget body;

  @override
  State<HeadlinePage> createState() => _HeadlinePageState();
}

class _HeadlinePageState extends State<HeadlinePage> {
  final _headline = HeadlineTracker();
  final _headlineGone = ValueNotifier(false);
  final _body = GlobalKey();

  @override
  void dispose() {
    _headlineGone.dispose();
    super.dispose();
  }

  bool _checkHeadline(Notification notification) {
    final body = _body.currentContext?.findRenderObject();
    if (body is RenderBox && body.hasSize) {
      // The body starts where the bar ends.
      _headlineGone.value = _headline.isAbove(
        body.localToGlobal(Offset.zero).dy,
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FramedAppBar(
        title: _BarTitle(title: widget.title, shown: _headlineGone),
      ),
      body: NotificationListener<ScrollMetricsNotification>(
        onNotification: _checkHeadline,
        child: NotificationListener<ScrollNotification>(
          onNotification: _checkHeadline,
          child: KeyedSubtree(
            key: _body,
            child: HeadlineScope(tracker: _headline, child: widget.body),
          ),
        ),
      ),
    );
  }
}

/// The name in the bar while the page's own is out of sight. It develops
/// cell by cell, quicker than content does, as it answers the finger.
/// Screen readers already have the page's heading.
class _BarTitle extends StatelessWidget {
  const _BarTitle({required this.title, required this.shown});

  static const _duration = Duration(milliseconds: 300);

  final String title;
  final ValueListenable<bool> shown;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ValueListenableBuilder<bool>(
        valueListenable: shown,
        builder: (context, shown, _) => DitherSwitcher(
          duration: _duration,
          child: shown && title.isNotEmpty
              ? PageTitle(key: ValueKey(title), title: title)
              : const SizedBox.shrink(key: ValueKey('no_title')),
        ),
      ),
    );
  }
}
