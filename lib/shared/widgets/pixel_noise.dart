import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:iris/shared/utils/ordered_dither.dart';

const _cellSize = 3.0;
const _shimmerCellSize = 2.0;

/// Faint square-pixel noise: how the app shows something that is still on
/// its way. The cells are the halftone's, the density drifts across the
/// surface in a slow diagonal wave, and each cell only re-rolls every few
/// frames, so it shimmers without flickering.
///
/// Nothing shows for the first [delay], so content that arrives quickly
/// never flashes a placeholder. Without [animate] it is one still frame.
class PixelNoiseEffect extends PaintingEffect {
  const PixelNoiseEffect({
    required this.color,
    this.cell = _cellSize,
    this.animate = true,
  }) : super(
         duration: animate ? _clockSpan : Duration.zero,
         upperBound: _clockSeconds,
       );

  /// The animation value counts seconds since the noise appeared.
  static const _clockSeconds = 3600.0;
  static const _clockSpan = Duration(seconds: 3600);

  static const delay = Duration(milliseconds: 150);

  final Color color;
  final double cell;
  final bool animate;

  /// The effect in the current theme, still when animations are off.
  factory PixelNoiseEffect.of(BuildContext context) => PixelNoiseEffect(
    color: Theme.of(context).colorScheme.onSurface,
    animate: !MediaQuery.disableAnimationsOf(context),
  );

  /// The paint for [rect] at [t] seconds.
  @override
  Paint createPaint(double t, Rect rect, TextDirection? textDirection) {
    final frames = _NoiseFrames.of(color);
    return Paint()
      ..shader = _tileShader(animate ? frames.at(t) : frames.still, rect, cell);
  }

  @override
  PaintingEffect lerp(PaintingEffect? other, double t) {
    if (other is! PixelNoiseEffect) return this;
    return PixelNoiseEffect(
      color: Color.lerp(color, other.color, t)!,
      cell: t < 0.5 ? cell : other.cell,
      animate: t < 0.5 ? animate : other.animate,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PixelNoiseEffect &&
      other.color == color &&
      other.cell == cell &&
      other.animate == animate;

  @override
  int get hashCode => Object.hash(color, cell, animate);
}

enum _PixelNoiseKind { placeholder, shimmer, surface }

/// Iris's pixel noise for a placeholder, a shimmering loading label, or a
/// busy button surface.
class PixelNoise extends StatefulWidget {
  const PixelNoise({super.key})
    : _kind = _PixelNoiseKind.placeholder,
      _shimmerChild = null;

  /// Sweeps an ordered-dither highlight wave across [child] (e.g. a loading
  /// label) so ongoing work reads clearly without ellipses.
  const PixelNoise.shimmer({required Widget child, super.key})
    : _kind = _PixelNoiseKind.shimmer,
      _shimmerChild = child;

  /// Paints the same sweeping ordered-dither wave across a button's fill.
  const PixelNoise.surface({super.key})
    : _kind = _PixelNoiseKind.surface,
      _shimmerChild = null;

  final _PixelNoiseKind _kind;
  final Widget? _shimmerChild;

  @override
  State<PixelNoise> createState() => _PixelNoiseState();
}

class _PixelNoiseState extends State<PixelNoise>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController.unbounded(vsync: this)
    ..addListener(_advanceShimmer);
  ui.Image? _lastShimmerFrame;

  void _advanceShimmer() {
    if (widget._kind != _PixelNoiseKind.shimmer) return;
    final frame = _SweepFrames.textMask.at(_clock.value);
    if (frame != _lastShimmerFrame) {
      setState(() => _lastShimmerFrame = frame);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (animate && !_clock.isAnimating) {
      _clock.repeat(
        min: 0,
        max: PixelNoiseEffect._clockSeconds,
        period: PixelNoiseEffect._clockSpan,
      );
    } else if (!animate) {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    return switch (widget._kind) {
      _PixelNoiseKind.shimmer => RepaintBoundary(
        child: ShaderMask(
          shaderCallback: (bounds) {
            final frames = _SweepFrames.textMask;
            final frame = animate ? frames.at(_clock.value) : frames.still;
            return _tileShader(frame, bounds, _shimmerCellSize);
          },
          blendMode: BlendMode.dstIn,
          child: widget._shimmerChild!,
        ),
      ),
      _PixelNoiseKind.surface => SizedBox.expand(
        child: CustomPaint(
          painter: _SurfaceSweepPainter(
            frames: _SweepFrames.surfaceOf(
              Theme.of(context).colorScheme.onSurface,
            ),
            animate: animate,
            clock: _clock,
          ),
        ),
      ),
      _PixelNoiseKind.placeholder => SizedBox.expand(
        child: CustomPaint(
          painter: _PixelNoisePainter(PixelNoiseEffect.of(context), _clock),
        ),
      ),
    };
  }
}

class _PixelNoisePainter extends CustomPainter {
  _PixelNoisePainter(this.effect, this.clock) : super(repaint: clock);

  final PixelNoiseEffect effect;
  final Animation<double> clock;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, effect.createPaint(clock.value, bounds, null));
  }

  @override
  bool shouldRepaint(_PixelNoisePainter old) => old.effect != effect;
}

class _SurfaceSweepPainter extends CustomPainter {
  _SurfaceSweepPainter({
    required this.frames,
    required this.animate,
    required this.clock,
  }) : super(repaint: animate ? clock : null);

  final _SweepFrames frames;
  final bool animate;
  final Animation<double> clock;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final frame = animate ? frames.at(clock.value) : frames.still;
    canvas.drawRect(
      bounds,
      Paint()..shader = _tileShader(frame, bounds, _cellSize),
    );
  }

  @override
  bool shouldRepaint(_SurfaceSweepPainter old) =>
      old.frames != frames || old.animate != animate;
}

ui.ImageShader _tileShader(ui.Image image, Rect rect, double cell) =>
    ui.ImageShader(
      image,
      TileMode.repeated,
      TileMode.repeated,
      Float64List.fromList([
        cell, 0, 0, 0, //
        0, cell, 0, 0,
        0, 0, 1, 0,
        rect.left, rect.top, 0, 1,
      ]),
      filterQuality: FilterQuality.none,
    );

/// Ordered 4×4 Bayer dithered wave sweeping diagonally left to right.
/// Used both as a dstIn opacity mask for loading text and as a subtle fill
/// sweep across busy buttons.
class _SweepFrames {
  _SweepFrames(
    Color color, {
    required double valleyAlpha,
    required double peakAlpha,
    required double stillAlpha,
  }) : still = _renderSolid(color, stillAlpha),
       loop = [
         for (var frame = 0; frame < _loopFrames; frame++)
           _render(
             color,
             valleyAlpha: valleyAlpha,
             peakAlpha: peakAlpha,
             frame: frame,
           ),
       ];

  static const _tile = 64;
  static const _fps = 12;
  static const _loopFrames = 16;

  static final textMask = _SweepFrames(
    Colors.white,
    valleyAlpha: 0.40,
    peakAlpha: 1.0,
    stillAlpha: 0.70,
  );

  static final _surfaceCache = <int, _SweepFrames>{};

  static _SweepFrames surfaceOf(Color color) =>
      _surfaceCache[color.toARGB32()] ??= _SweepFrames(
        color,
        valleyAlpha: 0,
        peakAlpha: 0.11,
        stillAlpha: 0.05,
      );

  final ui.Image still;
  final List<ui.Image> loop;

  ui.Image at(double seconds) {
    final frame = (seconds * _fps).floor();
    return loop[frame % _loopFrames];
  }

  static ui.Image _renderSolid(Color color, double alpha) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (alpha > 0) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, _tile * 1.0, _tile * 1.0),
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(_tile, _tile);
    picture.dispose();
    return image;
  }

  static ui.Image _render(
    Color color, {
    required double valleyAlpha,
    required double peakAlpha,
    required int frame,
  }) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const side = _tile * 1.0;
    if (valleyAlpha > 0) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, side, side),
        Paint()..color = color.withValues(alpha: valleyAlpha),
      );
    }
    final points = <double>[];
    for (var y = 0; y < _tile; y++) {
      for (var x = 0; x < _tile; x++) {
        // Seamless 45° diagonal sweep across the 64×64 tile.
        final phase = ((x + y) / _tile) - (frame / _loopFrames);
        final wave = 0.5 + 0.5 * math.cos(2 * math.pi * phase);
        final crest = math.pow(wave, 2.5);
        final threshold = (bayerLevel(x, y) + 0.5) / 16.0;
        if (crest > threshold) {
          points.addAll([x + 0.5, y + 0.5]);
        }
      }
    }
    if (points.isNotEmpty) {
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.fromList(points),
        Paint()
          ..color = color.withValues(alpha: peakAlpha)
          ..blendMode = BlendMode.src
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.square
          ..isAntiAlias = false,
      );
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(_tile, _tile);
    picture.dispose();
    return image;
  }
}

/// A short loop of repeating tiles, one cell per texel.
class _NoiseFrames {
  _NoiseFrames(
    Color color, {
    double initialAlpha = 0,
    double baseAlpha = 0.035,
    double speckleAlpha = 0.14,
  }) {
    ui.Image render(double fade, int frame) => _render(
      color,
      baseAlpha: ui.lerpDouble(initialAlpha, baseAlpha, fade)!,
      speckleAlpha: ui.lerpDouble(initialAlpha, speckleAlpha, fade)!,
      frame: frame,
    );
    blank = render(0, 0);
    fadeIn = [
      for (var step = 1; step <= _fadeSteps; step++)
        render(step / (_fadeSteps + 1), 0),
    ];
    loop = [for (var frame = 0; frame < _loopFrames; frame++) render(1, frame)];
  }

  static const _tile = 96;
  static const _fps = 10;
  static const _loopFrames = 20;
  static const _fadeSteps = 2;

  /// Frames a cell keeps its draw before it re-rolls.
  static const _hold = 4;

  /// The wave's length along the diagonal, in cells; divides the tile, so
  /// the tiles join without a seam.
  static const _waveLength = 48;

  static final _cache = <int, _NoiseFrames>{};

  static _NoiseFrames of(Color color) =>
      _cache[color.toARGB32()] ??= _NoiseFrames(color);

  late final ui.Image blank;
  late final List<ui.Image> fadeIn;
  late final List<ui.Image> loop;

  ui.Image get still => loop.first;

  ui.Image at(double seconds) {
    final frame =
        ((seconds - PixelNoiseEffect.delay.inMilliseconds / 1000) * _fps)
            .floor();
    if (frame < 0) return blank;
    if (frame < fadeIn.length) return fadeIn[frame];
    return loop[(frame - fadeIn.length) % loop.length];
  }

  static ui.Image _render(
    Color color, {
    required double baseAlpha,
    required double speckleAlpha,
    required int frame,
  }) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const side = _tile * 1.0;
    if (baseAlpha > 0) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, side, side),
        Paint()..color = color.withValues(alpha: baseAlpha),
      );
    }
    if (speckleAlpha != baseAlpha) {
      final points = <double>[];
      for (var y = 0; y < _tile; y++) {
        for (var x = 0; x < _tile; x++) {
          if (_lit(x, y, frame)) points.addAll([x + 0.5, y + 0.5]);
        }
      }
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.fromList(points),
        Paint()
          ..color = color.withValues(alpha: speckleAlpha)
          ..blendMode = BlendMode.src
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.square
          ..isAntiAlias = false,
      );
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(_tile, _tile);
    picture.dispose();
    return image;
  }

  static bool _lit(int x, int y, int frame) {
    final phase = 2 * math.pi * ((x + y) / _waveLength - frame / _loopFrames);
    final crest = math.pow(0.5 + 0.5 * math.sin(phase), 2);
    final density = 0.08 + 0.42 * crest;
    final offset = (_random(x, y, 0) * _hold).floor();
    final draw = ((frame + offset) ~/ _hold) % (_loopFrames ~/ _hold);
    return _random(x, y, draw + 1) < density;
  }

  /// A stable random number in 0…1 for a cell and a draw.
  static double _random(int x, int y, int draw) {
    var h = (x * 0x27d4eb2d ^ y * 0x165667b1 ^ draw * 0x9e3779b9) & 0xffffffff;
    h = ((h ^ (h >> 15)) * 0x85ebca6b) & 0xffffffff;
    h = ((h ^ (h >> 13)) * 0xc2b2ae35) & 0xffffffff;
    h ^= h >> 16;
    return (h & 0xffffff) / 0x1000000;
  }
}
