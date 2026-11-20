import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  testWidgets('text shimmers in place and holds a frame with reduced motion', (
    tester,
  ) async {
    const key = Key('loading label');
    const label = 'Checking session';
    Widget app({required bool reduced}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: const Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: PixelNoise.shimmer(child: Text(label)),
            ),
          ),
        ),
      ),
    );

    Future<List<int>> pixels() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      return (await tester.runAsync(() async {
        final image = boundary.toImageSync();
        try {
          final bytes = (await image.toByteData())!;
          return bytes.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      }))!;
    }

    await tester.pumpWidget(app(reduced: false));
    await tester.pump(const Duration(milliseconds: 450));
    final rect = tester.getRect(find.text(label));
    final first = await pixels();
    await tester.pump(const Duration(milliseconds: 500));
    expect(await pixels(), isNot(first));
    expect(tester.getRect(find.text(label)), rect);
    expect(find.bySemanticsLabel(label), findsOneWidget);

    await tester.pumpWidget(app(reduced: true));
    final still = await pixels();
    await tester.pump(const Duration(seconds: 1));
    expect(await pixels(), still);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
