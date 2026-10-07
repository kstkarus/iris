import 'dart:math' as math;
import 'dart:typed_data';

/// 4×4 Bayer thresholds, 0…15: the classic ordered-dither screen.
const bayer4 = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];

/// The Bayer threshold (0…15) of grid cell ([x], [y]).
int bayerLevel(int x, int y) => bayer4[(y & 3) * 4 + (x & 3)];

/// Colour (RGB, 0…1, three values per cell) of [rgba] scaled to cover a
/// [width]×[height] grid, like [BoxFit.cover]: each grid cell averages the
/// source pixels under it.
///
/// [alignX] and [alignY] (-1…1) choose which part of an image that does
/// not share the grid's shape is kept.
Float32List coverSample(
  Uint8List rgba, {
  required int sourceWidth,
  required int sourceHeight,
  required int width,
  required int height,
  double alignX = 0,
  double alignY = 0,
}) {
  final result = Float32List(width * height * 3);
  if (sourceWidth <= 0 || sourceHeight <= 0 || width <= 0 || height <= 0) {
    return result;
  }
  final scale = math.max(width / sourceWidth, height / sourceHeight);
  final left = (sourceWidth - width / scale) * (alignX + 1) / 2;
  final top = (sourceHeight - height / scale) * (alignY + 1) / 2;

  for (var y = 0; y < height; y++) {
    final y0 = (top + y / scale).floor().clamp(0, sourceHeight - 1);
    final y1 = (top + (y + 1) / scale).ceil().clamp(y0 + 1, sourceHeight);
    for (var x = 0; x < width; x++) {
      final x0 = (left + x / scale).floor().clamp(0, sourceWidth - 1);
      final x1 = (left + (x + 1) / scale).ceil().clamp(x0 + 1, sourceWidth);
      var r = 0.0, g = 0.0, b = 0.0;
      for (var sy = y0; sy < y1; sy++) {
        var offset = (sy * sourceWidth + x0) * 4;
        for (var sx = x0; sx < x1; sx++) {
          r += rgba[offset];
          g += rgba[offset + 1];
          b += rgba[offset + 2];
          offset += 4;
        }
      }
      final count = (y1 - y0) * (x1 - x0) * 255;
      final cell = (y * width + x) * 3;
      result[cell] = r / count;
      result[cell + 1] = g / count;
      result[cell + 2] = b / count;
    }
  }
  return result;
}

/// RGBA pixels of [rgb] with each channel reduced to [levels] steps by
/// ordered dithering: a limited palette (125 colours at 5 levels) whose
/// in-between tones are mixed from the Bayer screen.
Uint8List orderedDither(Float32List rgb, {required int width, int levels = 5}) {
  final count = rgb.length ~/ 3;
  final pixels = Uint8List(count * 4);
  final steps = math.max(1, levels - 1);
  for (var index = 0; index < count; index++) {
    final threshold = (bayerLevel(index % width, index ~/ width) + 0.5) / 16;
    for (var channel = 0; channel < 3; channel++) {
      final value = rgb[index * 3 + channel].clamp(0.0, 1.0) * steps;
      final base = value.floor();
      final level = math.min(steps, value - base > threshold ? base + 1 : base);
      pixels[index * 4 + channel] = (level * 255 / steps).round();
    }
    pixels[index * 4 + 3] = 255;
  }
  return pixels;
}
