import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/presentation/widgets/player_countdown.dart';

void main() {
  const plateKey = Key('plate');

  Future<void> pump(
    WidgetTester tester, {
    required Duration? duration,
    required VoidCallback onElapsed,
    bool running = true,
    bool noMotion = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: noMotion),
          child: Scaffold(
            body: Center(
              child: PlayerCountdown(
                duration: duration,
                onElapsed: onElapsed,
                running: running,
                child: const PlayerCountdownBar(
                  color: Colors.white,
                  child: SizedBox(key: plateKey, width: 200, height: 48),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The bar's share of the plate's width.
  double? barShare(WidgetTester tester) {
    final bar = find.byKey(const Key('player_countdown_bar'));
    if (bar.evaluate().isEmpty) return null;
    return tester.widget<FractionallySizedBox>(bar).widthFactor;
  }

  testWidgets('draws the time left and ends when it runs out', (tester) async {
    var elapsed = 0;
    await pump(
      tester,
      duration: const Duration(seconds: 8),
      onElapsed: () => elapsed++,
    );
    await tester.pump();
    expect(barShare(tester), 1);

    await tester.pump(const Duration(seconds: 2));
    expect(barShare(tester), closeTo(0.75, 0.01));
    expect(elapsed, 0);

    await tester.pump(const Duration(seconds: 6));
    expect(barShare(tester), 0);
    expect(elapsed, 1);
  });

  testWidgets('waits while there is no duration, then counts in full', (
    tester,
  ) async {
    var elapsed = 0;
    await pump(tester, duration: null, onElapsed: () => elapsed++);
    await tester.pump(const Duration(seconds: 20));
    expect(barShare(tester), isNull);
    expect(elapsed, 0);

    await pump(
      tester,
      duration: const Duration(seconds: 8),
      onElapsed: () => elapsed++,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    expect(elapsed, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(elapsed, 1);
  });

  testWidgets('holds full under the pointer and resumes on leaving', (
    tester,
  ) async {
    var elapsed = 0;
    await pump(
      tester,
      duration: const Duration(seconds: 8),
      onElapsed: () => elapsed++,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byKey(plateKey)));
    await tester.pump();
    // It fills back up rather than jumping.
    await tester.pump(PlayerCountdown.refill ~/ 2);
    expect(barShare(tester), inExclusiveRange(0.5, 1));
    await tester.pump(PlayerCountdown.refill);
    expect(barShare(tester), 1);
    await tester.pump(const Duration(seconds: 30));
    expect(barShare(tester), 1);
    expect(elapsed, 0);

    // Leaving starts the count over.
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    expect(elapsed, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(elapsed, 1);
    await mouse.removePointer();
  });

  testWidgets('stands where it is while not running, then goes on from '
      'there', (tester) async {
    var elapsed = 0;
    void onElapsed() => elapsed++;
    await pump(
      tester,
      duration: const Duration(seconds: 8),
      onElapsed: onElapsed,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // Paused: the bar stays at three quarters, however long.
    await pump(
      tester,
      duration: const Duration(seconds: 8),
      onElapsed: onElapsed,
      running: false,
    );
    await tester.pump(const Duration(minutes: 1));
    expect(barShare(tester), closeTo(0.75, 0.01));
    expect(elapsed, 0);

    // Playing again: the six seconds left, not eight.
    await pump(
      tester,
      duration: const Duration(seconds: 8),
      onElapsed: onElapsed,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(elapsed, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(elapsed, 1);
  });

  testWidgets('waits for the video before it starts to count', (tester) async {
    var elapsed = 0;
    await pump(
      tester,
      duration: const Duration(seconds: 8),
      onElapsed: () => elapsed++,
      running: false,
    );
    await tester.pump(const Duration(seconds: 20));
    expect(barShare(tester), 1);
    expect(elapsed, 0);
  });

  testWidgets('fills back up at once when the system asks for less motion', (
    tester,
  ) async {
    await pump(
      tester,
      duration: const Duration(seconds: 8),
      onElapsed: () {},
      noMotion: true,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byKey(plateKey)));
    await tester.pump();
    await tester.pump();
    expect(barShare(tester), 1);
    await mouse.removePointer();
  });

  testWidgets('counts in full time with the system\'s animations off', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    var elapsed = 0;
    await pump(
      tester,
      duration: const Duration(seconds: 8),
      onElapsed: () => elapsed++,
      noMotion: true,
    );
    await tester.pump();

    await tester.pump(const Duration(seconds: 2));
    expect(barShare(tester), closeTo(0.75, 0.01));
    expect(elapsed, 0);
  });
}
