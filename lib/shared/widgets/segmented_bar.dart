import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Progress drawn as a row of equal blocks: filled ones in [color] (the
/// signal by default), the rest in [trackColor].
///
/// Blocks are stretched to fill the width exactly, so bars of the same
/// width line up block for block.
///
/// Changes of [value] light the blocks up in turn rather than jumping;
/// with [animateIn] the bar also fills from empty when it first shows.
///
/// With [ditherTrack] the unfilled blocks are a halftone of [color]
/// instead: the first one dense, the rest a checkerboard of square
/// [ditherPixel]s, so a large bar fades out rather than stopping.
class SegmentedBar extends StatelessWidget {
  const SegmentedBar({
    required this.value,
    this.height = 6,
    this.segment = 8,
    this.gap = 2,
    this.color,
    this.trackColor,
    this.ditherTrack = false,
    this.ditherPixel = 2,
    this.animateIn = false,
    this.semanticsLabel,
    super.key,
  });

  /// From 0 to 1.
  final double value;
  final double height;

  /// Preferred block width; the actual one is adjusted to the bar's width.
  final double segment;
  final double gap;
  final Color? color;
  final Color? trackColor;
  final bool ditherTrack;
  final double ditherPixel;
  final bool animateIn;
  final String? semanticsLabel;

  static const _duration = Duration(milliseconds: 420);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticsLabel,
      value: '${(clamped * 100).round()}%',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: animateIn ? 0 : clamped, end: clamped),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : _duration,
          curve: Curves.easeOutCubic,
          builder: (context, filled, _) => CustomPaint(
            painter: _SegmentsPainter(
              filled: filled,
              segment: segment,
              gap: gap,
              color: color ?? scheme.tertiary,
              trackColor: trackColor ?? scheme.surfaceContainerHighest,
              ditherPixel: ditherTrack ? ditherPixel : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// A heavy rule of solid blocks that opens a major part of a page, where a
/// hairline would be too quiet.
class BlockRule extends StatelessWidget {
  const BlockRule({this.height = 12, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SegmentsPainter(
            filled: 1,
            segment: 84,
            gap: 4,
            color: scheme.onSurface.withValues(alpha: 0.86),
            trackColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}

/// A thin dashed separator: long dashes with short gaps, the rule that
/// divides rows and table cells.
class SegmentedRule extends StatelessWidget {
  const SegmentedRule({this.color, this.thickness = 1, super.key});

  final Color? color;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: thickness,
      width: double.infinity,
      child: CustomPaint(
        painter: _SegmentsPainter(
          filled: 1,
          segment: 56,
          gap: 4,
          color: color ?? Theme.of(context).colorScheme.outline,
          trackColor: Colors.transparent,
        ),
      ),
    );
  }
}

class _SegmentsPainter extends CustomPainter {
  const _SegmentsPainter({
    required this.filled,
    required this.segment,
    required this.gap,
    required this.color,
    required this.trackColor,
    this.ditherPixel,
  });

  final double filled;
  final double segment;
  final double gap;
  final Color color;
  final Color trackColor;

  /// Halftone pixel for unfilled blocks; null paints them in [trackColor].
  final double? ditherPixel;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final count = math.max(1, ((size.width + gap) / (segment + gap)).floor());
    final width = (size.width - gap * (count - 1)) / count;
    // Any progress shows at least one block; only the end fills the last.
    final lit = filled <= 0
        ? 0
        : filled >= 1 || count == 1
        ? count
        : (filled * count).floor().clamp(1, count - 1);
    final on = Paint()..color = color;
    final off = Paint()..color = trackColor;
    final pixel = ditherPixel;
    final halftone = Path();
    for (var index = 0; index < count; index++) {
      final block = Rect.fromLTWH(index * (width + gap), 0, width, size.height);
      if (index < lit) {
        canvas.drawRect(block, on);
      } else if (pixel == null) {
        canvas.drawRect(block, off);
      } else {
        _addHalftone(halftone, block, pixel, dense: index == lit);
      }
    }
    if (pixel != null) canvas.drawPath(halftone, on);
  }

  /// Three pixels in four for the block next to the filled ones, every
  /// other pixel after it.
  static void _addHalftone(
    Path path,
    Rect block,
    double pixel, {
    required bool dense,
  }) {
    final columns = (block.width / pixel).floor();
    final rows = (block.height / pixel).floor();
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        final lit = dense ? !(x.isOdd && y.isOdd) : (x + y).isEven;
        if (!lit) continue;
        path.addRect(
          Rect.fromLTWH(
            block.left + x * pixel,
            block.top + y * pixel,
            pixel,
            pixel,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SegmentsPainter old) =>
      old.filled != filled ||
      old.segment != segment ||
      old.gap != gap ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.ditherPixel != ditherPixel;
}
