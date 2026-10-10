import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:iris/shared/utils/ordered_dither.dart';

/// Progress drawn as a row of equal blocks: filled ones in [color] (the
/// signal by default), the rest in [trackColor].
///
/// Blocks are stretched to fill the width exactly, so bars of the same
/// width line up block for block.
///
/// Changes of [value] light the blocks up in turn rather than jumping;
/// with [animateIn] the bar also fills from empty when it first shows.
///
/// With [ditherTrack], for a large bar, the unfilled blocks are a
/// checkerboard of square [ditherPixel]s in [trackColor], so the rest of
/// the bar recedes, and the block where progress stops fills in Bayer
/// order by its own share.
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
              trackColor:
                  trackColor ??
                  (ditherTrack
                      ? scheme.onSurface.withValues(alpha: 0.3)
                      : scheme.surfaceContainerHighest),
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
              ditherPixel: ditherTrack ? ditherPixel : null,
            ),
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
    this.devicePixelRatio = 1,
    this.ditherPixel,
  });

  final double filled;
  final double segment;
  final double gap;
  final Color color;
  final Color trackColor;

  /// Block edges and halftone pixels land on whole device pixels, so a
  /// scaled screen does not smear them.
  final double devicePixelRatio;

  /// Halftone pixel; null paints blocks solid.
  final double? ditherPixel;

  double _snap(double value) =>
      (value * devicePixelRatio).roundToDouble() / devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final pixel = ditherPixel;
    if (pixel != null) {
      _paintHalftone(canvas, size, _snapPixel(pixel));
      return;
    }
    final count = math.max(1, ((size.width + gap) / (segment + gap)).floor());
    final width = (size.width - gap * (count - 1)) / count;
    _paintSolid(canvas, [
      for (var index = 0; index < count; index++)
        Rect.fromLTRB(
          _snap(index * (width + gap)),
          0,
          _snap(index * (width + gap) + width),
          _snap(size.height),
        ),
    ]);
  }

  void _paintSolid(Canvas canvas, List<Rect> blocks) {
    final count = blocks.length;
    // Any progress shows at least one block; only the end fills the last.
    final lit = filled <= 0
        ? 0
        : filled >= 1 || count == 1
        ? count
        : (filled * count).floor().clamp(1, count - 1);
    final on = Paint()..color = color;
    final off = Paint()..color = trackColor;
    for (final (index, block) in blocks.indexed) {
      canvas.drawRect(block, index < lit ? on : off);
    }
  }

  /// Whole blocks in [color]; the block where progress stops fills in
  /// Bayer order by its own share, so a sliver of progress is a few pixels
  /// rather than a whole block; the rest is a checkerboard of [trackColor].
  ///
  /// Every block is the same odd number of pixels each way, the nearest to
  /// [segment]: the checkerboard then starts and ends on a lit pixel at
  /// every edge, and solid and halftone blocks line up. The number of
  /// blocks follows from that size, so the gaps stay close to [gap].
  void _paintHalftone(Canvas canvas, Size size, double pixel) {
    final columns = _nearestOdd(segment / pixel);
    final rows = _oddFloor(size.height / pixel);
    if (rows == 0) return;
    final blockWidth = columns * pixel;
    final blockHeight = rows * pixel;
    final count = math.max(
      1,
      ((size.width + gap) / (blockWidth + gap)).floor(),
    );
    final spacing = count > 1
        ? (size.width - count * blockWidth) / (count - 1)
        : 0.0;
    final top = _snap((size.height - blockHeight) / 2);
    final exact = filled.clamp(0.0, 1.0) * count;
    final lit = exact.floor();
    // Of 16 Bayer levels; anything above zero shows at least one.
    final level = lit < count && exact > lit
        ? ((exact - lit) * 16).ceil().clamp(1, 16)
        : 0;
    final solid = Path();
    final progress = Path();
    final track = Path();
    for (var index = 0; index < count; index++) {
      final left = count > 1
          ? _snap(index * (blockWidth + spacing))
          : _snap((size.width - blockWidth) / 2);
      if (index < lit) {
        solid.addRect(Rect.fromLTWH(left, top, blockWidth, blockHeight));
        continue;
      }
      // The filling block shows only its own pixels: grey between them
      // would read as noise.
      final filling = index == lit && level > 0;
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < columns; x++) {
          final on = filling ? bayerLevel(x, y) < level : (x + y).isEven;
          if (!on) continue;
          (filling ? progress : track).addRect(
            Rect.fromLTWH(left + x * pixel, top + y * pixel, pixel, pixel),
          );
        }
      }
    }
    final on = Paint()..color = color;
    canvas
      ..drawPath(track, Paint()..color = trackColor)
      ..drawPath(solid, on)
      ..drawPath(progress, on);
  }

  double _snapPixel(double pixel) =>
      math.max(1, (pixel * devicePixelRatio).round()) / devicePixelRatio;

  /// The odd whole number nearest to [value], the smaller one on a tie.
  static int _nearestOdd(double value) {
    final below = _oddFloor(value);
    if (below == 0) return 1;
    return value - below > below + 2 - value ? below + 2 : below;
  }

  static int _oddFloor(double value) {
    final whole = value.floor();
    if (whole <= 1) return math.max(whole, 0);
    return whole.isOdd ? whole : whole - 1;
  }

  @override
  bool shouldRepaint(_SegmentsPainter old) =>
      old.filled != filled ||
      old.segment != segment ||
      old.gap != gap ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.devicePixelRatio != devicePixelRatio ||
      old.ditherPixel != ditherPixel;
}
