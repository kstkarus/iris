import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:iris/shared/utils/ordered_dither.dart';

/// Dissolves scrolled-away content at the top edge of a vertical scroll view
/// using the app's 4×4 Bayer halftone screen instead of a hard clip or divider.
///
/// While the list rests at the top (`pixels <= 0`) nothing is painted; as the
/// user scrolls, a lightweight surface-colored dither strip emerges over the
/// top [height] logical pixels without introducing a `saveLayer` over the list.
class DitherScrollEdge extends StatefulWidget {
  const DitherScrollEdge({
    required this.child,
    this.height = 20.0,
    this.cell = 2.0,
    this.color,
    super.key,
  });

  final Widget child;
  final double height;
  final double cell;
  final Color? color;

  @override
  State<DitherScrollEdge> createState() => _DitherScrollEdgeState();
}

class _DitherScrollEdgeState extends State<DitherScrollEdge> {
  double _extent = 0;

  void _updateFromMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;
    final next = (metrics.pixels / widget.height).clamp(0.0, 1.0);
    if ((next - _extent).abs() > 0.01 ||
        (next == 0 && _extent != 0) ||
        (next == 1 && _extent != 1)) {
      setState(() => _extent = next);
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    _updateFromMetrics(notification.metrics);
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    if (notification.depth != 0) return false;
    _updateFromMetrics(notification.metrics);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.color ?? Theme.of(context).colorScheme.surface;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            if (_extent > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        heightFactor: _extent,
                        child: SizedBox(
                          height: widget.height,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _BayerEdgePainter(
                              color: surface,
                              cell: widget.cell,
                              steps: (widget.height / widget.cell)
                                  .round()
                                  .clamp(4, 32),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BayerEdgePainter extends CustomPainter {
  const _BayerEdgePainter({
    required this.color,
    required this.cell,
    required this.steps,
  });

  static final Map<int, ui.Image> _cache = {};

  final Color color;
  final double cell;
  final int steps;

  static ui.Image _stripFor(int steps) {
    return _cache.putIfAbsent(steps, () {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()
        ..color = const ui.Color(0xFFFFFFFF)
        ..isAntiAlias = false;
      for (var y = 0; y < steps; y++) {
        // Top row is solid (16/16) to conceal the clip boundary; bottom row
        // tapers to 0/16 so scrolled rows dissolve cell by cell into surface.
        final open = y == 0
            ? 16
            : ((steps - 1 - y) * 16 / (steps - 1)).round().clamp(0, 16);
        for (var x = 0; x < 4; x++) {
          if (bayerLevel(x, y % 4) < open) {
            canvas.drawRect(
              ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
              paint,
            );
          }
        }
      }
      final picture = recorder.endRecording();
      final image = picture.toImageSync(4, steps);
      picture.dispose();
      return image;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final image = _stripFor(steps);
    final shader = ui.ImageShader(
      image,
      ui.TileMode.repeated,
      ui.TileMode.clamp,
      Float64List.fromList([
        cell, 0, 0, 0, //
        0, cell, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
      ]),
      filterQuality: ui.FilterQuality.none,
    );
    final paint = Paint()
      ..shader = shader
      ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _BayerEdgePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.cell != cell ||
      oldDelegate.steps != steps;
}
