import 'package:flutter/widgets.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// A bitmap, 7×7 for icons: `#` is a lit pixel. Drawn square by square, so
/// icons keep the hard pixel edge of the rest of the interface at any size.
class PixelGlyph {
  const PixelGlyph._(this.rows);

  final List<String> rows;

  int get width => rows.first.length;

  int get height => rows.length;

  /// The app's mark, also its launcher icon: an eye. Seven rows like the
  /// icons, wider than they are.
  static const eye = PixelGlyph._([
    '...#####...',
    '.##.....##.',
    '#...###...#',
    '#...###...#',
    '#...###...#',
    '.##.....##.',
    '...#####...',
  ]);

  static const arrowLeft = PixelGlyph._([
    '...#...',
    '..#....',
    '.#.....',
    '#######',
    '.#.....',
    '..#....',
    '...#...',
  ]);

  static const arrowRight = PixelGlyph._([
    '...#...',
    '....#..',
    '.....#.',
    '#######',
    '.....#.',
    '....#..',
    '...#...',
  ]);

  /// Opens a menu below.
  static const expand = PixelGlyph._([
    '.......',
    '.......',
    '#######',
    '.#####.',
    '..###..',
    '...#...',
    '.......',
  ]);

  static const close = PixelGlyph._([
    '#.....#',
    '##...##',
    '.##.##.',
    '..###..',
    '.##.##.',
    '##...##',
    '#.....#',
  ]);

  static const more = PixelGlyph._([
    '.......',
    '.......',
    '.......',
    '#..#..#',
    '.......',
    '.......',
    '.......',
  ]);

  static const search = PixelGlyph._([
    '.###...',
    '#...#..',
    '#...#..',
    '#...#..',
    '.###...',
    '.....#.',
    '......#',
  ]);

  static const tune = PixelGlyph._([
    '..#....',
    '#######',
    '..#....',
    '.......',
    '....#..',
    '#######',
    '....#..',
  ]);

  static const sort = PixelGlyph._([
    '#######',
    '.......',
    '#####..',
    '.......',
    '###....',
    '.......',
    '#......',
  ]);

  static const check = PixelGlyph._([
    '.......',
    '.....##',
    '....##.',
    '##.##..',
    '.###...',
    '..#....',
    '.......',
  ]);

  /// Centred by its bounds: a triangle looks heavier at its flat side, so
  /// one drawn from the grid's first column reads as off to the left.
  static const play = PixelGlyph._([
    '..#....',
    '..##...',
    '..###..',
    '..####.',
    '..###..',
    '..##...',
    '..#....',
  ]);

  static const pause = PixelGlyph._([
    '##...##',
    '##...##',
    '##...##',
    '##...##',
    '##...##',
    '##...##',
    '##...##',
  ]);

  static const download = PixelGlyph._([
    '...#...',
    '...#...',
    '.#####.',
    '..###..',
    '...#...',
    '.......',
    '#######',
  ]);

  static const refresh = PixelGlyph._([
    '.####.#',
    '#....##',
    '#...###',
    '#......',
    '#.....#',
    '.#...#.',
    '..###..',
  ]);

  static const paste = PixelGlyph._([
    '.##.##.',
    '#.###.#',
    '#.....#',
    '#.###.#',
    '#.....#',
    '#.###.#',
    '#######',
  ]);

  // Player controls.

  static const skipNext = PixelGlyph._([
    '#.....#',
    '##....#',
    '###...#',
    '####..#',
    '###...#',
    '##....#',
    '#.....#',
  ]);

  /// A list with a play mark: the episodes of the release.
  static const episodes = PixelGlyph._([
    '#######',
    '.......',
    '###.#..',
    '....##.',
    '###.###',
    '....##.',
    '###.#..',
  ]);

  /// A frame with lines of text: audio and subtitle tracks.
  static const subtitles = PixelGlyph._([
    '#######',
    '#.....#',
    '#.....#',
    '#.###.#',
    '#.....#',
    '#.#.###',
    '#######',
  ]);

  static const settings = PixelGlyph._([
    '..#.#..',
    '.#####.',
    '##...##',
    '.#...#.',
    '##...##',
    '.#####.',
    '..#.#..',
  ]);

  /// A page with its corner folded: a file.
  static const file = PixelGlyph._([
    '#####..',
    '#...##.',
    '#....##',
    '#.....#',
    '#.....#',
    '#.....#',
    '#######',
  ]);

  /// A small window in the corner of a large one.
  static const pictureInPicture = PixelGlyph._([
    '#######',
    '#.....#',
    '#.....#',
    '#..####',
    '#..####',
    '#..####',
    '#######',
  ]);

  static const fullscreen = PixelGlyph._([
    '##...##',
    '#.....#',
    '.......',
    '.......',
    '.......',
    '#.....#',
    '##...##',
  ]);

  static const fullscreenExit = PixelGlyph._([
    '.#...#.',
    '##...##',
    '.......',
    '.......',
    '.......',
    '##...##',
    '.#...#.',
  ]);

  static const volumeUp = PixelGlyph._([
    '..#...#',
    '.##.#.#',
    '###.#.#',
    '###.#.#',
    '###.#.#',
    '.##.#.#',
    '..#...#',
  ]);

  static const volumeDown = PixelGlyph._([
    '..#....',
    '.##.#..',
    '###.#..',
    '###.#..',
    '###.#..',
    '.##.#..',
    '..#....',
  ]);

  static const plus = PixelGlyph._([
    '...#...',
    '...#...',
    '...#...',
    '#######',
    '...#...',
    '...#...',
    '...#...',
  ]);

  static const minus = PixelGlyph._([
    '.......',
    '.......',
    '.......',
    '#######',
    '.......',
    '.......',
    '.......',
  ]);

  /// A sun: the screen's brightness.
  static const brightness = PixelGlyph._([
    '#..#..#',
    '.#...#.',
    '..###..',
    '#.###.#',
    '..###..',
    '.#...#.',
    '#..#..#',
  ]);

  /// A closed padlock: the screen takes no touches.
  static const lock = PixelGlyph._([
    '..###..',
    '.#...#.',
    '.#...#.',
    '#######',
    '###.###',
    '###.###',
    '#######',
  ]);

  /// The padlock with its shackle let go on the right.
  static const lockOpen = PixelGlyph._([
    '..###..',
    '.#...#.',
    '.#.....',
    '#######',
    '###.###',
    '###.###',
    '#######',
  ]);

  static const volumeOff = PixelGlyph._([
    '..#....',
    '.##....',
    '###.#.#',
    '###..#.',
    '###.#.#',
    '.##....',
    '..#....',
  ]);
}

/// An icon drawn from a [PixelGlyph], sized and coloured by the ambient
/// [IconTheme] like [Icon].
///
/// [size] is the glyph's height; a wider glyph is wider in proportion.
/// Pixels are whole logical pixels, so the glyph may be a little smaller
/// than [size]; it stays centred. With [fineGrain] they are whole device
/// pixels instead, for a size between multiples of seven on a dense screen.
///
/// With [fill], a share from 0 to 1, the glyph shows progress: that share
/// of its pixels, from the bottom row up, is in [color], the rest in
/// [trackColor].
class PixelIcon extends StatelessWidget {
  const PixelIcon(
    this.glyph, {
    this.size,
    this.color,
    this.semanticLabel,
    this.fineGrain = false,
    this.fill,
    this.trackColor,
    super.key,
  });

  final PixelGlyph glyph;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final bool fineGrain;
  final double? fill;

  /// The unfilled pixels; [color] at a third of its opacity when unset.
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final size = this.size ?? iconTheme.size ?? 24;
    var color = this.color ?? iconTheme.color ?? const Color(0xFF000000);
    final opacity = iconTheme.opacity;
    if (opacity != null && opacity != 1) {
      color = color.withValues(alpha: color.a * opacity);
    }
    // In a loading placeholder the glyph is one block of noise, like the
    // button it usually sits in.
    final icon = Skeleton.unite(
      child: SizedBox(
        width: size * glyph.width / glyph.height,
        height: size,
        child: CustomPaint(
          painter: _PixelGlyphPainter(
            glyph: glyph,
            color: color,
            fill: fill?.clamp(0.0, 1.0),
            trackColor: trackColor ?? color.withValues(alpha: color.a / 3),
            size: size,
            pixelRatio: fineGrain
                ? MediaQuery.maybeDevicePixelRatioOf(context) ?? 1
                : 1,
          ),
        ),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: icon);
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: icon),
    );
  }
}

class _PixelGlyphPainter extends CustomPainter {
  const _PixelGlyphPainter({
    required this.glyph,
    required this.color,
    required this.fill,
    required this.trackColor,
    required this.size,
    required this.pixelRatio,
  });

  final PixelGlyph glyph;
  final Color color;
  final double? fill;
  final Color trackColor;

  /// The icon's own size; a parent may stretch the canvas around it (an
  /// input decoration does), and the glyph keeps to this size, centred.
  final double size;

  /// What a cell is a whole number of: 1 for logical pixels, the device's
  /// ratio for its own.
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    double snap(double value) =>
        (value * pixelRatio).roundToDouble() / pixelRatio;
    final cell = snap(size / glyph.height).clamp(1 / pixelRatio, 64.0);
    final origin = Offset(
      snap((canvasSize.width - cell * glyph.width) / 2),
      snap((canvasSize.height - cell * glyph.height) / 2),
    );
    // Bottom row first, so a fill rises through the glyph.
    final lit = [
      for (var y = glyph.height - 1; y >= 0; y--)
        for (var x = 0; x < glyph.width; x++)
          if (glyph.rows[y].codeUnitAt(x) == 0x23) (x, y),
    ];
    final fill = this.fill;
    final filled = fill == null ? lit.length : (fill * lit.length).round();
    final path = Path();
    final track = Path();
    for (final (index, (x, y)) in lit.indexed) {
      (index < filled ? path : track).addRect(
        Rect.fromLTWH(origin.dx + x * cell, origin.dy + y * cell, cell, cell),
      );
    }
    canvas
      ..drawPath(track, Paint()..color = trackColor)
      ..drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PixelGlyphPainter old) =>
      old.glyph != glyph ||
      old.color != color ||
      old.fill != fill ||
      old.trackColor != trackColor ||
      old.size != size ||
      old.pixelRatio != pixelRatio;
}
