import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/dithered_image.dart';
import 'package:iris/shared/widgets/pixel_noise.dart';

// A 1×1 transparent PNG; the toggle does not depend on the picture.
final _pixel = MemoryImage(
  Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]),
);

Widget _app(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Center(child: SizedBox(width: 60, height: 90, child: child)),
    ),
  );
}

/// An image that never arrives, or fails at once.
class _PendingImage extends ImageProvider<_PendingImage> {
  const _PendingImage({this.fails = false});

  final bool fails;

  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _PendingImage key,
    ImageDecoderCallback decode,
  ) => _Completer(fails: fails);
}

class _Completer extends ImageStreamCompleter {
  _Completer({required bool fails}) {
    // After the image has had a chance to listen.
    if (fails) {
      scheduleMicrotask(
        () => reportError(exception: Exception('no picture'), silent: true),
      );
    }
  }
}

String _tooltip(WidgetTester tester) =>
    tester.widget<Tooltip>(find.byType(Tooltip)).message!;

void main() {
  testWidgets('a tap swaps to the original and back', (tester) async {
    await tester.pumpWidget(
      _app(
        DitheredImage(
          image: _pixel,
          showOriginalLabel: 'Original',
          showHalftoneLabel: 'Halftone',
        ),
      ),
    );

    expect(_tooltip(tester), 'Original');

    // The noise keeps running until a picture arrives, so step the clock
    // instead of settling.
    await tester.tap(find.byType(DitheredImage));
    await tester.pump(DitheredImage.revealDuration ~/ 4);
    expect(_tooltip(tester), 'Original', reason: 'still mostly halftone');
    await tester.pump(DitheredImage.revealDuration);
    expect(_tooltip(tester), 'Halftone');

    await tester.tap(find.byType(DitheredImage));
    await tester.pump(DitheredImage.revealDuration);
    await tester.pump(DitheredImage.revealDuration);
    expect(_tooltip(tester), 'Original');
  });

  testWidgets('swaps at once when animations are off', (tester) async {
    await tester.pumpWidget(
      _app(
        DitheredImage(
          image: _pixel,
          showOriginalLabel: 'Original',
          showHalftoneLabel: 'Halftone',
        ),
        disableAnimations: true,
      ),
    );

    await tester.tap(find.byType(DitheredImage));
    await tester.pump();

    expect(_tooltip(tester), 'Halftone');
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('without labels it is a plain picture', (tester) async {
    await tester.pumpWidget(_app(DitheredImage(image: _pixel)));

    expect(find.byType(Tooltip), findsNothing);
    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('shows noise until the picture arrives', (tester) async {
    await tester.pumpWidget(_app(const DitheredImage(image: _PendingImage())));

    expect(find.byType(PixelNoise), findsOneWidget);
  });

  testWidgets('a picture that fails leaves a still panel', (tester) async {
    await tester.pumpWidget(
      _app(const DitheredImage(image: _PendingImage(fails: true))),
    );
    await tester.pump();

    expect(find.byType(PixelNoise), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
