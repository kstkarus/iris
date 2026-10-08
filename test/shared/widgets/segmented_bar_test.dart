import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/segmented_bar.dart';

void main() {
  const signal = Color(0xFF00FF00);
  const track = Color(0xFF808080);

  Future<void> pumpBar(WidgetTester tester, double value) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 240,
            child: SegmentedBar(
              value: value,
              height: 18,
              segment: 20,
              gap: 4,
              color: signal,
              trackColor: track,
              ditherTrack: true,
            ),
          ),
        ),
      ),
    );
  }

  // Eleven blocks of 9 by 9 two-pixel cells, 4.2 apart; the first at x = 0.
  testWidgets('a sliver of progress is a few pixels, not a whole block', (
    tester,
  ) async {
    await pumpBar(tester, 0.007);

    expect(
      find.byType(SegmentedBar),
      paints
        ..path(color: track)
        ..path(color: signal, excludes: [const Offset(3, 1)])
        ..path(
          color: signal,
          // Bayer order: the first two levels light cells (0, 0) and (2, 2).
          includes: [const Offset(1, 1), const Offset(5, 5)],
          excludes: [const Offset(3, 1), const Offset(1, 3)],
        ),
    );
  });

  testWidgets('the rest is a checkerboard, lit at both edges of a block', (
    tester,
  ) async {
    await pumpBar(tester, 0);

    expect(
      find.byType(SegmentedBar),
      paints..path(
        color: track,
        includes: [const Offset(1, 1), const Offset(17, 1)],
        excludes: [const Offset(3, 1)],
      ),
    );
  });

  testWidgets('blocks keep the nominal gap', (tester) async {
    await pumpBar(tester, 0);

    // The second block starts after one 18-pixel block and a 4.2 gap.
    expect(
      find.byType(SegmentedBar),
      paints..path(
        color: track,
        includes: [const Offset(23, 1)],
        excludes: [const Offset(20, 1)],
      ),
    );
  });
}
