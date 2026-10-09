import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/segmented_choice.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required int selected,
    bool disableAnimations = false,
    ValueChanged<int>? onSelected,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: SegmentedChoice<int>(
                  selected: selected,
                  onSelected: onSelected ?? (_) {},
                  options: const [
                    SegmentedOption(value: 0, label: 'Lower'),
                    SegmentedOption(value: 1, label: 'Standard'),
                    SegmentedOption(value: 2, label: 'Higher'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Where the fill of the chosen cell starts, from the control's left.
  double fillLeft(WidgetTester tester) {
    final control = tester.getRect(find.byType(SegmentedChoice<int>));
    final fill = tester.getRect(
      find.descendant(
        of: find.byType(AnimatedPositioned),
        matching: find.byType(ColoredBox),
      ),
    );
    return fill.left - control.left;
  }

  testWidgets('reports the tapped option', (tester) async {
    int? picked;
    await pump(tester, selected: 1, onSelected: (value) => picked = value);

    await tester.tap(find.text('Higher'));

    expect(picked, 2);
  });

  testWidgets('slides the fill to a new choice', (tester) async {
    await pump(tester, selected: 0);
    expect(fillLeft(tester), closeTo(0, 0.5));

    await pump(tester, selected: 2);
    await tester.pump(const Duration(milliseconds: 80));
    final midway = fillLeft(tester);
    expect(midway, greaterThan(1));
    expect(midway, lessThan(199));

    await tester.pumpAndSettle();
    expect(fillLeft(tester), closeTo(200, 0.5));
  });

  testWidgets('moves at once when motion is reduced', (tester) async {
    await pump(tester, selected: 0, disableAnimations: true);

    await pump(tester, selected: 2, disableAnimations: true);
    await tester.pump();

    expect(fillLeft(tester), closeTo(200, 0.5));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
