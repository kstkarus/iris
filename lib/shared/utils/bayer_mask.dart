import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:iris/shared/utils/ordered_dither.dart';

/// Masks that open a surface cell by cell in the order of the 4×4 Bayer
/// screen, the same order the halftone is mixed in.
///
/// With `open` n, [shader] is opaque over the cells whose level is below n:
/// 0 hides everything and [steps] shows it all. Use it with
/// [ui.BlendMode.dstIn] to keep only those cells of what was painted.
abstract final class BayerMask {
  static const steps = 16;

  static final _open = List<ui.Image?>.filled(steps + 1, null);
  static final _closed = List<ui.Image?>.filled(steps + 1, null);

  /// A repeating mask with square [cell]s whose top-left cell starts at
  /// [origin]. With [inverse] it covers the cells that are still closed.
  static ui.Shader shader(
    int open, {
    required double cell,
    ui.Offset origin = ui.Offset.zero,
    bool inverse = false,
  }) {
    final level = open.clamp(0, steps);
    final cache = inverse ? _closed : _open;
    final tile = cache[level] ??= _tile(level, inverse: inverse);
    return ui.ImageShader(
      tile,
      ui.TileMode.repeated,
      ui.TileMode.repeated,
      Float64List.fromList([
        cell, 0, 0, 0, //
        0, cell, 0, 0,
        0, 0, 1, 0,
        origin.dx, origin.dy, 0, 1,
      ]),
      filterQuality: ui.FilterQuality.none,
    );
  }

  static ui.Image _tile(int open, {required bool inverse}) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF)
      ..isAntiAlias = false;
    for (var y = 0; y < 4; y++) {
      for (var x = 0; x < 4; x++) {
        if ((bayerLevel(x, y) < open) != inverse) {
          canvas.drawRect(
            ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
            paint,
          );
        }
      }
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(4, 4);
    picture.dispose();
    return image;
  }
}
