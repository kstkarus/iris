import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/network_image.dart';
import 'package:iris/shared/widgets/square_avatar.dart';

void main() {
  Future<ui.Image> createTestImage() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint());
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    picture.dispose();
    return image;
  }

  testWidgets('fades in a loaded avatar again on a memory cache hit', (
    tester,
  ) async {
    final image = await tester.runAsync(createTestImage);
    final previous = networkImage;
    addTearDown(() => networkImage = previous);

    final pending = Completer<ImageInfo>();
    final provider = _TestImageProvider(pending.future);
    networkImage = (_) => provider;
    const app = MaterialApp(
      home: Center(child: SquareAvatar(url: 'avatar', size: 48)),
    );
    Future<void> expectFade() async {
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    }

    await tester.pumpWidget(app);
    pending.complete(ImageInfo(image: image!));
    await tester.pump();
    await expectFade();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app);
    await expectFade();
  });

  testWidgets('reveals avatar immediately when animations are disabled', (
    tester,
  ) async {
    final image = await tester.runAsync(createTestImage);
    final previous = networkImage;
    addTearDown(() => networkImage = previous);

    final pending = Completer<ImageInfo>();
    final provider = _TestImageProvider(pending.future);
    networkImage = (_) => provider;

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(child: SquareAvatar(url: 'async', size: 48)),
        ),
      ),
    );

    pending.complete(ImageInfo(image: image!));
    await tester.pump();
    await tester.pump();

    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(tester.hasRunningAnimations, isFalse);
  });
}

class _TestImageProvider extends ImageProvider<_TestImageProvider> {
  const _TestImageProvider(this.frame);

  final Future<ImageInfo> frame;

  @override
  Future<_TestImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _TestImageProvider key,
    ImageDecoderCallback decode,
  ) => _TestCompleter(frame);
}

class _TestCompleter extends ImageStreamCompleter {
  _TestCompleter(Future<ImageInfo> frame) {
    frame.then(setImage);
  }
}
