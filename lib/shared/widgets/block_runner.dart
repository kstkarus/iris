import 'package:flutter/material.dart';

/// A square wait indicator: one block runs around a 3×3 ring. Square like an
/// icon or play button whose place it takes, and a loop rather than a bar of
/// segments, so it never reads as a level or a share loaded.
class BlockRunner extends StatefulWidget {
  const BlockRunner({
    required this.color,
    required this.trackColor,
    this.cell = 12,
    this.gap = 3,
    super.key,
  });

  final Color color;
  final Color trackColor;
  final double cell;
  final double gap;

  /// One step per block, in the noise's 10 fps.
  static const step = Duration(milliseconds: 100);

  @override
  State<BlockRunner> createState() => _BlockRunnerState();
}

class _BlockRunnerState extends State<BlockRunner>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: BlockRunner.step * _ring.length,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final side = widget.cell * 3 + widget.gap * 2;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(side),
        painter: _RunnerPainter(
          progress: _controller,
          color: widget.color,
          trackColor: widget.trackColor,
          cell: widget.cell,
          gap: widget.gap,
        ),
      ),
    );
  }
}

/// The square's outer cells, clockwise from the top left.
const _ring = [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2), (1, 2), (0, 2), (0, 1)];

class _RunnerPainter extends CustomPainter {
  _RunnerPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.cell,
    required this.gap,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final Color trackColor;
  final double cell;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final head = (progress.value * _ring.length).floor() % _ring.length;
    final paint = Paint();
    for (var index = 0; index < _ring.length; index++) {
      final behind = (head - index) % _ring.length;
      paint.color = switch (behind) {
        0 => color,
        // A one-block trail gives the loop its direction.
        1 => color.withValues(alpha: color.a * 0.45),
        _ => trackColor,
      };
      final (column, row) = _ring[index];
      canvas.drawRect(
        Rect.fromLTWH(column * (cell + gap), row * (cell + gap), cell, cell),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RunnerPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.cell != cell ||
      oldDelegate.gap != gap;
}
