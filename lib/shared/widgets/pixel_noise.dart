import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

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
    this.cell = 3,
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
      ..shader = ui.ImageShader(
        animate ? frames.at(t) : frames.still,
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

/// A box filled with [PixelNoiseEffect]: the placeholder for a picture
/// that has not arrived yet.
class PixelNoise extends StatefulWidget {
  const PixelNoise({super.key});

  @override
  State<PixelNoise> createState() => _PixelNoiseState();
}

class _PixelNoiseState extends State<PixelNoise>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController.unbounded(
    vsync: this,
  );

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
    return SizedBox.expand(
      child: CustomPaint(
        painter: _PixelNoisePainter(PixelNoiseEffect.of(context), _clock),
      ),
    );
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

/// The noise as a short loop of repeating tiles, one cell per texel, made
/// once per colour.
class _NoiseFrames {
  _NoiseFrames(Color color)
    : blank = _render(color, fade: 0, frame: 0),
      fadeIn = [
        for (var step = 1; step <= _fadeSteps; step++)
          _render(color, fade: step / (_fadeSteps + 1), frame: 0),
      ],
      loop = [
        for (var frame = 0; frame < _loopFrames; frame++)
          _render(color, fade: 1, frame: frame),
      ];

  static const _tile = 96;
  static const _fps = 10;
  static const _loopFrames = 20;
  static const _fadeSteps = 2;

  /// Frames a cell keeps its draw before it re-rolls.
  static const _hold = 4;

  /// The wave's length along the diagonal, in cells; divides the tile, so
  /// the tiles join without a seam.
  static const _waveLength = 48;

  static const _baseAlpha = 0.035;
  static const _litAlpha = 0.14;

  static final _cache = <int, _NoiseFrames>{};

  static _NoiseFrames of(Color color) =>
      _cache[color.toARGB32()] ??= _NoiseFrames(color);

  final ui.Image blank;
  final List<ui.Image> fadeIn;
  final List<ui.Image> loop;

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
    required double fade,
    required int frame,
  }) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const side = _tile * 1.0;
    if (fade > 0) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, side, side),
        Paint()..color = color.withValues(alpha: _baseAlpha * fade),
      );
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
          ..color = color.withValues(alpha: _litAlpha * fade)
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
