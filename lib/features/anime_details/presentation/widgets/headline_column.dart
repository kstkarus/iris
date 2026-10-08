import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The two children of a [HeadlineColumn].
enum HeadlineColumnSlot { headline, rest }

/// A headline over the rest of a column, the whole as tall as [height]:
/// the rest is laid out first and the headline gets the height left over,
/// so a long title sets smaller instead of pushing the rest down.
///
/// The headline always gets at least [minHeadlineHeight] (what it needs at
/// its smallest); when that does not fit, the column grows past [height].
class HeadlineColumn
    extends SlottedMultiChildRenderObjectWidget<HeadlineColumnSlot, RenderBox> {
  const HeadlineColumn({
    required this.headline,
    required this.rest,
    required this.height,
    required this.minHeadlineHeight,
    super.key,
  });

  final Widget headline;
  final Widget rest;
  final double height;
  final double minHeadlineHeight;

  @override
  Iterable<HeadlineColumnSlot> get slots => HeadlineColumnSlot.values;

  @override
  Widget? childForSlot(HeadlineColumnSlot slot) => switch (slot) {
    HeadlineColumnSlot.headline => headline,
    HeadlineColumnSlot.rest => rest,
  };

  @override
  RenderHeadlineColumn createRenderObject(BuildContext context) =>
      RenderHeadlineColumn(
        height: height,
        minHeadlineHeight: minHeadlineHeight,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderHeadlineColumn renderObject,
  ) {
    renderObject
      ..height = height
      ..minHeadlineHeight = minHeadlineHeight;
  }
}

class RenderHeadlineColumn extends RenderBox
    with SlottedContainerRenderObjectMixin<HeadlineColumnSlot, RenderBox> {
  RenderHeadlineColumn({
    required double height,
    required double minHeadlineHeight,
  }) : _height = height,
       _minHeadlineHeight = minHeadlineHeight;

  double _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  double _minHeadlineHeight;
  set minHeadlineHeight(double value) {
    if (value == _minHeadlineHeight) return;
    _minHeadlineHeight = value;
    markNeedsLayout();
  }

  RenderBox? get _headline => childForSlot(HeadlineColumnSlot.headline);
  RenderBox? get _rest => childForSlot(HeadlineColumnSlot.rest);

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final rest = _rest!;
    final headline = _headline!;
    rest.layout(BoxConstraints(maxWidth: width), parentUsesSize: true);
    final budget = math.max(_height - rest.size.height, _minHeadlineHeight);
    headline.layout(
      BoxConstraints(maxWidth: width, maxHeight: budget),
      parentUsesSize: true,
    );
    (headline.parentData! as BoxParentData).offset = Offset.zero;
    (rest.parentData! as BoxParentData).offset = Offset(
      0,
      headline.size.height,
    );
    size = constraints.constrain(
      Size(width, headline.size.height + rest.size.height),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(
        child,
        offset + (child.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children) {
      final offset = (child.parentData! as BoxParentData).offset;
      final hit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
