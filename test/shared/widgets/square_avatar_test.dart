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

  testWidgets('fades in asynchronous avatar loads and skips sync frames', (
    tester,
  ) async {
    final image = await tester.runAsync(createTestImage);
    final previous = networkImage;
    addTearDown(() => networkImage = previous);

    final pending = Completer<ImageInfo>();
    networkImage = (url) => url == 'sync'
        ? _TestImageProvider(image: image!, synchronous: true)
        : _TestImageProvider(future: pending.future);

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: SquareAvatar(url: 'async', size: 48)),
      ),
    );

    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );

    pending.complete(ImageInfo(image: image!.clone()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: SquareAvatar(url: 'sync', size: 48)),
      ),
    );
    expect(find.byType(AnimatedOpacity), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reveals avatar immediately when animations are disabled', (
    tester,
  ) async {
    final image = await tester.runAsync(createTestImage);
    final previous = networkImage;
    addTearDown(() => networkImage = previous);

    final pending = Completer<ImageInfo>();
    networkImage = (_) => _TestImageProvider(future: pending.future);

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

    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
    expect(tester.hasRunningAnimations, isFalse);
  });
}

class _TestImageProvider extends ImageProvider<_TestImageProvider> {
  const _TestImageProvider({this.image, this.future, this.synchronous = false});

  final ui.Image? image;
  final Future<ImageInfo>? future;
  final bool synchronous;

  @override
  Future<_TestImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _TestImageProvider key,
    ImageDecoderCallback decode,
  ) => _TestCompleter(image: image, future: future, synchronous: synchronous);
}

class _TestCompleter extends ImageStreamCompleter {
  _TestCompleter({
    ui.Image? image,
    Future<ImageInfo>? future,
    bool synchronous = false,
  }) {
    if (synchronous && image != null) {
      setImage(ImageInfo(image: image));
    } else if (future != null) {
      future.then(setImage);
    }
  }
}
