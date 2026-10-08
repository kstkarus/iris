import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/pixel_noise.dart';

const _side = 96;

/// Alpha of each cell of one noise tile at [t] seconds.
Future<List<int>> _cells(PixelNoiseEffect effect, double t) async {
  const rect = Rect.fromLTWH(0, 0, _side * 1.0, _side * 1.0);
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(rect, effect.createPaint(t, rect, null));
  final image = await recorder.endRecording().toImage(_side, _side);
  final bytes = await image.toByteData();
  return [for (var i = 3; i < bytes!.lengthInBytes; i += 4) bytes.getUint8(i)];
}

const _effect = PixelNoiseEffect(color: Colors.white, cell: 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stays empty for the first moment', () async {
    final cells = await _cells(_effect, 0.1);
    expect(cells.every((alpha) => alpha == 0), isTrue);
  });

  test('is faint and sparse once it shows', () async {
    final cells = await _cells(_effect, 1);
    final lit = cells.where((alpha) => alpha > 20).length / cells.length;
    expect(cells.reduce((a, b) => a > b ? a : b), lessThan(48));
    expect(lit, inInclusiveRange(0.1, 0.35));
  });

  test('moves, a few cells at a time, and loops', () async {
    final now = await _cells(_effect, 1);
    final next = await _cells(_effect, 1.1);
    final changed = [
      for (var i = 0; i < now.length; i++) now[i] != next[i],
    ].where((c) => c).length;
    expect(changed, greaterThan(0));
    expect(changed / now.length, lessThan(0.2));

    expect(await _cells(_effect, 3), await _cells(_effect, 1));
  });

  test('is one still, visible frame without animation', () async {
    const still = PixelNoiseEffect(
      color: Colors.white,
      cell: 1,
      animate: false,
    );
    final first = await _cells(still, 0);
    expect(first.any((alpha) => alpha > 0), isTrue);
    expect(await _cells(still, 5), first);
  });

  testWidgets('the widget clock runs unless motion is reduced', (tester) async {
    Widget app({bool disableAnimations = false}) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: const PixelNoise(),
        ),
      );
    }

    await tester.pumpWidget(app());
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(app(disableAnimations: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('effects with the same settings are equal', () {
    expect(
      const PixelNoiseEffect(color: Colors.white),
      const PixelNoiseEffect(color: Colors.white),
    );
    expect(
      const PixelNoiseEffect(color: Colors.white),
      isNot(const PixelNoiseEffect(color: Colors.black)),
    );
  });
}
