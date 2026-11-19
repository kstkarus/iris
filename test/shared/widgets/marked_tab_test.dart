import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/marked_tab.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool selected,
    bool disableAnimations = false,
    VoidCallback? onTap,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(
            body: MarkedTab(
              label: 'Catalog',
              selected: selected,
              onTap: onTap ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  TextStyle labelStyle(WidgetTester tester) => tester
      .widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.text('Catalog'),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      )
      .style;

  testWidgets('invokes onTap when pressed', (tester) async {
    var taps = 0;
    await pump(tester, selected: false, onTap: () => taps++);

    await tester.tap(find.text('Catalog'));

    expect(taps, 1);
  });

  testWidgets('animates marker and label style together on selection', (
    tester,
  ) async {
    await pump(tester, selected: false);
    final label = find.text('Catalog');
    final labelStart = tester.getTopLeft(label).dx;
    final unselectedColor = labelStyle(tester).color!;
    expect(labelStyle(tester).fontWeight, FontWeight.w400);

    await pump(tester, selected: true);
    await tester.pump(const Duration(milliseconds: 110));
    final midwayColor = labelStyle(tester).color!;
    expect(midwayColor, isNot(equals(unselectedColor)));
    expect(tester.getTopLeft(label).dx, labelStart);
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpAndSettle();
    expect(labelStyle(tester).fontWeight, FontWeight.w500);
    expect(labelStyle(tester).color, isNot(equals(midwayColor)));
    expect(tester.getTopLeft(label).dx, labelStart);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('updates immediately when animations are disabled', (
    tester,
  ) async {
    await pump(tester, selected: false, disableAnimations: true);

    await pump(tester, selected: true, disableAnimations: true);
    await tester.pump();

    expect(labelStyle(tester).fontWeight, FontWeight.w500);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
