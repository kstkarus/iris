import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/utils/bayer_mask.dart';

/// Alpha of each pixel of a 4×4 area painted with [shader].
Future<List<int>> _alphas(ui.Shader shader) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(
    recorder,
  ).drawRect(const ui.Rect.fromLTWH(0, 0, 4, 4), ui.Paint()..shader = shader);
  final image = await recorder.endRecording().toImage(4, 4);
  final bytes = await image.toByteData();
  return [for (var i = 3; i < bytes!.lengthInBytes; i += 4) bytes.getUint8(i)];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('opens one cell of every 16 per step, in Bayer order', () async {
    for (final open in [0, 1, 5, 8, 15, 16]) {
      final alphas = await _alphas(BayerMask.shader(open, cell: 1));
      expect(alphas.where((a) => a == 255).length, open, reason: '$open');
    }
    // Level 0 sits top-left, level 1 at (2, 2).
    expect((await _alphas(BayerMask.shader(1, cell: 1)))[0], 255);
    expect((await _alphas(BayerMask.shader(2, cell: 1)))[2 * 4 + 2], 255);
  });

  test('the inverse covers exactly the cells still closed', () async {
    final open = await _alphas(BayerMask.shader(6, cell: 1));
    final closed = await _alphas(BayerMask.shader(6, cell: 1, inverse: true));
    for (var i = 0; i < 16; i++) {
      expect(open[i] + closed[i], 255, reason: 'pixel $i');
    }
  });
}
