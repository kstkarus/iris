import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:iris/shared/utils/bayer_mask.dart';

/// [AnimatedSwitcher] parts that swap two children cell by cell, in the
/// order of the Bayer screen: the new child develops in exactly the cells
/// the old one leaves, so the two never show at once in one cell.
abstract final class DitherTransition {
  static const duration = Duration(milliseconds: 520);

  /// Side of one cell, the halftone's.
  static const cell = 3.0;

  static Widget transition(Widget child, Animation<double> animation) =>
      _DitherTransition(animation: animation, child: child);

  /// Children stacked from the top-left; the tallest sets the height.
  static Widget layout(Widget? current, List<Widget> previous) => Stack(
    alignment: AlignmentDirectional.topStart,
    children: [...previous, ?current],
  );

  /// Like [layout], with every child filling the box.
  static Widget expandedLayout(Widget? current, List<Widget> previous) =>
      Stack(fit: StackFit.expand, children: [...previous, ?current]);
}

class _DitherTransition extends AnimatedWidget {
  const _DitherTransition({required Animation<double> animation, this.child})
    : super(listenable: animation);

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    // The outgoing child runs backwards; it keeps the cells the incoming
    // one has not taken yet.
    final leaving = switch (animation.status) {
      AnimationStatus.reverse || AnimationStatus.dismissed => true,
      _ => false,
    };
    final progress = leaving ? 1 - animation.value : animation.value;
    return BayerMasked(
      open: (progress * BayerMask.steps).round(),
      inverse: leaving,
      child: child,
    );
  }
}

/// Paints [child] only in the cells [BayerMask] opens at [open] (or, with
/// [inverse], only in those still closed). Fully open, the child paints
/// as usual, without a mask layer.
class BayerMasked extends SingleChildRenderObjectWidget {
  const BayerMasked({
    required this.open,
    this.inverse = false,
    this.cell = DitherTransition.cell,
    super.child,
    super.key,
  });

  final int open;
  final bool inverse;
  final double cell;

  @override
  RenderBayerMasked createRenderObject(BuildContext context) =>
      RenderBayerMasked(open: open, inverse: inverse, cell: cell);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderBayerMasked renderObject,
  ) {
    renderObject
      ..open = open
      ..inverse = inverse
      ..cell = cell;
  }
}

class RenderBayerMasked extends RenderProxyBox {
  RenderBayerMasked({
    required int open,
    required bool inverse,
    required double cell,
  }) : _open = open.clamp(0, BayerMask.steps),
       _inverse = inverse,
       _cell = cell;

  int _open;
  bool _inverse;
  double _cell;

  /// Cells the child shows in, out of [BayerMask.steps].
  int get _visible => _inverse ? BayerMask.steps - _open : _open;

  bool get _masked => _visible > 0 && _visible < BayerMask.steps;

  set open(int value) {
    final open = value.clamp(0, BayerMask.steps);
    if (open == _open) return;
    final wasMasked = _masked;
    _open = open;
    if (wasMasked != _masked) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  set inverse(bool value) {
    if (value == _inverse) return;
    final wasMasked = _masked;
    _inverse = value;
    if (wasMasked != _masked) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  set cell(double value) {
    if (value == _cell) return;
    _cell = value;
    markNeedsPaint();
  }

  @override
  ShaderMaskLayer? get layer => super.layer as ShaderMaskLayer?;

  @override
  bool get alwaysNeedsCompositing => child != null && _masked;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || _visible == 0) {
      layer = null;
      return;
    }
    if (!_masked) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = (layer ?? ShaderMaskLayer())
      ..shader = BayerMask.shader(_open, cell: _cell, inverse: _inverse)
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    context.pushLayer(layer!, super.paint, offset);
  }
}
