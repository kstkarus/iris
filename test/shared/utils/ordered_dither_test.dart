import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/utils/ordered_dither.dart';

Uint8List _image(int width, int height, int Function(int x, int y) value) {
  final pixels = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final offset = (y * width + x) * 4;
      final v = value(x, y);
      pixels
        ..[offset] = v
        ..[offset + 1] = 255 - v
        ..[offset + 2] = v
        ..[offset + 3] = 255;
    }
  }
  return pixels;
}

void main() {
  group('coverSample', () {
    test('averages the source pixels under each cell, per channel', () {
      final rgb = coverSample(
        _image(8, 8, (_, _) => 255),
        sourceWidth: 8,
        sourceHeight: 8,
        width: 2,
        height: 2,
      );

      for (var cell = 0; cell < 4; cell++) {
        expect(rgb[cell * 3], closeTo(1, 1e-6));
        expect(rgb[cell * 3 + 1], closeTo(0, 1e-6));
        expect(rgb[cell * 3 + 2], closeTo(1, 1e-6));
      }
    });

    test('crops a portrait source to a landscape grid around the centre', () {
      // Top half 0, bottom half 255; a 2×1 grid keeps the middle band.
      final rgb = coverSample(
        _image(4, 8, (_, y) => y < 4 ? 0 : 255),
        sourceWidth: 4,
        sourceHeight: 8,
        width: 2,
        height: 1,
      );

      expect(rgb[0], closeTo(0.5, 1e-6));
      expect(rgb[3], closeTo(0.5, 1e-6));
    });
  });

  group('orderedDither', () {
    test('keeps each channel to the allowed levels', () {
      final rgb = Float32List.fromList([
        for (var index = 0; index < 64 * 3; index++) (index % 97) / 96,
      ]);

      final pixels = orderedDither(rgb, width: 8, levels: 4);

      for (var index = 0; index < 64; index++) {
        for (var channel = 0; channel < 3; channel++) {
          expect(pixels[index * 4 + channel], isIn([0, 85, 170, 255]));
        }
        expect(pixels[index * 4 + 3], 255);
      }
    });

    test('mixes two levels evenly for the tone halfway between them', () {
      final rgb = Float32List.fromList([
        for (var index = 0; index < 64 * 3; index++) 0.5,
      ]);

      final pixels = orderedDither(rgb, width: 8, levels: 2);

      var lit = 0;
      for (var index = 0; index < 64; index++) {
        if (pixels[index * 4] == 255) lit++;
      }
      expect(lit, 32);
    });

    test('keeps pure colours as they are', () {
      final rgb = Float32List.fromList([1, 0, 0, 0, 0, 1]);

      final pixels = orderedDither(rgb, width: 2);

      expect(pixels.sublist(0, 4), [255, 0, 0, 255]);
      expect(pixels.sublist(4, 8), [0, 0, 255, 255]);
    });
  });
}
