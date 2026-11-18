import 'package:flutter/widgets.dart';

/// A layer may still paint as it leaves, but only the active layer receives input.
class ActiveLayer extends StatefulWidget {
  const ActiveLayer({required this.active, required this.child, super.key});

  final bool active;
  final Widget child;

  static List<Widget> switcherChildren(
    Widget? current,
    List<Widget> previous,
  ) => [
    for (final child in previous)
      ActiveLayer(key: child.key, active: false, child: child),
    if (current != null)
      ActiveLayer(key: current.key, active: true, child: current),
  ];

  @override
  State<ActiveLayer> createState() => _ActiveLayerState();
}

class _ActiveLayerState extends State<ActiveLayer> {
  ScrollController? _inactiveScroll;

  @override
  void dispose() {
    _inactiveScroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = context
        .dependOnInheritedWidgetOfExactType<PrimaryScrollController>();
    final controller = primary?.controller;
    final inactive = !widget.active;
    final content = ExcludeFocus(
      excluding: inactive,
      child: IgnorePointer(
        ignoring: inactive,
        child: ExcludeSemantics(excluding: inactive, child: widget.child),
      ),
    );
    if (primary == null || controller == null) {
      return PrimaryScrollController.none(child: content);
    }
    return PrimaryScrollController(
      // Keep the scroll view mounted when its controller changes with the layer.
      controller: inactive
          ? (_inactiveScroll ??= ScrollController())
          : controller,
      automaticallyInheritForPlatforms:
          primary.automaticallyInheritForPlatforms,
      scrollDirection: primary.scrollDirection,
      child: content,
    );
  }
}
