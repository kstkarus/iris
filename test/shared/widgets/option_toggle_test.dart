import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/option_toggle.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool selected,
    bool disableAnimations = false,
    ValueChanged<bool>? onChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(
            body: OptionToggle(
              label: 'Airings',
              selected: selected,
              onChanged: onChanged ?? (_) {},
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
              of: find.text('Airings'),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      )
      .style;

  testWidgets('reports toggled selection on tap', (tester) async {
    bool? value;
    await pump(tester, selected: false, onChanged: (next) => value = next);

    await tester.tap(find.text('Airings'));

    expect(value, isTrue);
  });

  testWidgets('animates label text style alongside the toggle box', (
    tester,
  ) async {
    await pump(tester, selected: false);
    final unselectedColor = labelStyle(tester).color!;
    expect(labelStyle(tester).fontWeight, FontWeight.w400);

    await pump(tester, selected: true);
    await tester.pump(const Duration(milliseconds: 80));
    final midwayColor = labelStyle(tester).color!;
    expect(midwayColor, isNot(equals(unselectedColor)));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpAndSettle();
    expect(labelStyle(tester).fontWeight, FontWeight.w500);
    expect(labelStyle(tester).color, isNot(equals(midwayColor)));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('snaps label style immediately when animations are disabled', (
    tester,
  ) async {
    await pump(tester, selected: false, disableAnimations: true);

    await pump(tester, selected: true, disableAnimations: true);
    await tester.pump();

    expect(labelStyle(tester).fontWeight, FontWeight.w500);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
