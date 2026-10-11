import 'package:flutter/widgets.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// A 7×7 bitmap: `#` is a lit pixel. Drawn square by square, so icons keep
/// the hard pixel edge of the rest of the interface at any size.
class PixelGlyph {
  const PixelGlyph._(this.rows);

  static const gridSize = 7;

  final List<String> rows;

  /// The app's mark: an iris with its pupil.
  static const iris = PixelGlyph._([
    '..###..',
    '.#...#.',
    '#..#..#',
    '#.###.#',
    '#..#..#',
    '.#...#.',
    '..###..',
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

  static const play = PixelGlyph._([
    '.#.....',
    '.##....',
    '.###...',
    '.####..',
    '.###...',
    '.##....',
    '.#.....',
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
/// Pixels are whole logical pixels, so the glyph may be a little smaller
/// than [size]; it stays centred.
class PixelIcon extends StatelessWidget {
  const PixelIcon(
    this.glyph, {
    this.size,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final PixelGlyph glyph;
  final double? size;
  final Color? color;
  final String? semanticLabel;

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
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _PixelGlyphPainter(glyph: glyph, color: color, size: size),
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
    required this.size,
  });

  final PixelGlyph glyph;
  final Color color;

  /// The icon's own size; a parent may stretch the canvas around it (an
  /// input decoration does), and the glyph keeps to this size, centred.
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    const grid = PixelGlyph.gridSize;
    final cell = (size / grid).roundToDouble().clamp(1.0, 64.0);
    final origin = Offset(
      ((canvasSize.width - cell * grid) / 2).roundToDouble(),
      ((canvasSize.height - cell * grid) / 2).roundToDouble(),
    );
    final path = Path();
    for (var y = 0; y < grid; y++) {
      final row = glyph.rows[y];
      for (var x = 0; x < grid; x++) {
        if (row.codeUnitAt(x) != 0x23) continue;
        path.addRect(
          Rect.fromLTWH(origin.dx + x * cell, origin.dy + y * cell, cell, cell),
        );
      }
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PixelGlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.size != size;
}
