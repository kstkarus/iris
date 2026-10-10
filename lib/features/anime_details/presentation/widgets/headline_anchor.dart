import 'package:flutter/widgets.dart';

/// Where the anime's name sits on the page, so the bar can take the name
/// over once it has scrolled under the bar.
class HeadlineTracker {
  final _anchors = <BuildContext>{};

  /// Whether the name lies wholly above [edge], the bar's lower edge in
  /// global coordinates. False while no name is laid out.
  bool isAbove(double edge) {
    if (_anchors.isEmpty) return false;
    // While the page swaps from noise to details both copies are laid
    // out; the name is gone only when every copy is.
    for (final anchor in _anchors) {
      final box = anchor.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return false;
      if (box.localToGlobal(Offset(0, box.size.height)).dy > edge) {
        return false;
      }
    }
    return true;
  }
}

/// Gives the [HeadlineAnchor]s below it their [tracker].
class HeadlineScope extends InheritedWidget {
  const HeadlineScope({required this.tracker, required super.child, super.key});

  final HeadlineTracker tracker;

  static HeadlineTracker? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HeadlineScope>()?.tracker;

  @override
  bool updateShouldNotify(HeadlineScope oldWidget) =>
      tracker != oldWidget.tracker;
}

/// Marks [child] as the anime's name for the nearest [HeadlineScope].
class HeadlineAnchor extends StatefulWidget {
  const HeadlineAnchor({required this.child, super.key});

  final Widget child;

  @override
  State<HeadlineAnchor> createState() => _HeadlineAnchorState();
}

class _HeadlineAnchorState extends State<HeadlineAnchor> {
  HeadlineTracker? _tracker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tracker = HeadlineScope.maybeOf(context);
    if (tracker == _tracker) return;
    _tracker?._anchors.remove(context);
    _tracker = tracker?.._anchors.add(context);
  }

  @override
  void dispose() {
    _tracker?._anchors.remove(context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
