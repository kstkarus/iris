import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A variable-height list that can open on any row without laying out the
/// rows before it.
class EpisodeListScrollView extends StatefulWidget {
  const EpisodeListScrollView({
    required this.itemCount,
    required this.targetIndex,
    required this.itemBuilder,
    required this.padding,
    super.key,
  });

  final int itemCount;
  final int targetIndex;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;

  @override
  State<EpisodeListScrollView> createState() => _EpisodeListScrollViewState();
}

class _EpisodeListScrollViewState extends State<EpisodeListScrollView> {
  static const _preferredAlignment = 0.3;
  final _scroll = ScrollController(keepScrollOffset: false);
  GlobalKey _reverse = GlobalKey();
  GlobalKey _forward = GlobalKey();
  double _anchor = _preferredAlignment;
  Size? _viewportSize;

  @override
  void didUpdateWidget(covariant EpisodeListScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetIndex != widget.targetIndex) {
      _reverse = GlobalKey();
      _forward = GlobalKey();
      _anchor = _preferredAlignment;
      _viewportSize = null;
    }
    if (oldWidget.itemCount != widget.itemCount ||
        oldWidget.padding != widget.padding) {
      _viewportSize = null;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _alignTarget(Size size) {
    _viewportSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _viewportSize != size) return;
      double extent(GlobalKey key) =>
          (key.currentContext?.findRenderObject() as RenderSliver?)
              ?.geometry
              ?.scrollExtent ??
          0;
      // Fit short ends without leaving extra scroll space past the list.
      final anchor = math
          .min(
            extent(_reverse) / size.height,
            math.max(_preferredAlignment, 1 - extent(_forward) / size.height),
          )
          .clamp(0.0, 1.0);
      if (_anchor != anchor) setState(() => _anchor = anchor);
    });
  }

  @override
  Widget build(BuildContext context) {
    final center = math.max(0, widget.targetIndex);
    final padding = widget.padding.resolve(Directionality.of(context));
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (center > 0 && size.height > 0 && size != _viewportSize) {
          _alignTarget(size);
        }
        return CustomScrollView(
          key: ValueKey(center),
          controller: _scroll,
          center: _forward,
          anchor: center == 0 ? 0 : _anchor,
          semanticChildCount: widget.itemCount,
          slivers: [
            if (center > 0)
              SliverPadding(
                key: _reverse,
                padding: padding.copyWith(bottom: 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        widget.itemBuilder(context, center - 1 - index),
                    childCount: center,
                    semanticIndexCallback: (_, index) => center - 1 - index,
                  ),
                ),
              ),
            SliverPadding(
              key: _forward,
              padding: center == 0 ? padding : padding.copyWith(top: 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      widget.itemBuilder(context, center + index),
                  childCount: widget.itemCount - center,
                  semanticIndexOffset: center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
