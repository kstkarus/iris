import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/dither_switcher.dart';

void main() {
  Future<void> pumpSwitcher(
    WidgetTester tester, {
    required Widget child,
    bool resize = false,
    bool collapse = false,
  }) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: DitherSwitcher(
          key: const ValueKey('switcher'),
          resize: resize,
          collapse: collapse,
          child: child,
        ),
      ),
    ),
  );

  double height(WidgetTester tester) =>
      tester.getSize(find.byKey(const ValueKey('switcher'))).height;

  const empty = SizedBox(key: ValueKey('empty'), width: 100);
  const row = SizedBox(key: ValueKey('row'), width: 100, height: 60);

  testWidgets('a growing child opens its space while it develops', (
    tester,
  ) async {
    await pumpSwitcher(tester, resize: true, child: empty);
    await pumpSwitcher(tester, resize: true, child: row);
    await tester.pump(const Duration(milliseconds: 260));

    expect(height(tester), inExclusiveRange(0, 60));
    await tester.pumpAndSettle();
    expect(height(tester), 60);
  });

  testWidgets('without resize the height changes at once', (tester) async {
    await pumpSwitcher(tester, child: empty);
    await pumpSwitcher(tester, child: row);

    expect(height(tester), 60);
  });

  testWidgets('a leaving child dissolves, then gives its height back', (
    tester,
  ) async {
    await pumpSwitcher(tester, collapse: true, child: row);
    await pumpSwitcher(tester, collapse: true, child: empty);
    await tester.pump(const Duration(milliseconds: 400));
    expect(height(tester), 60);

    await tester.pump(const Duration(milliseconds: 380));
    expect(height(tester), inExclusiveRange(0, 60));
    await tester.pumpAndSettle();
    expect(height(tester), 0);
  });

  testWidgets('a child swaps at once when animations are off', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DitherSwitcher(collapse: true, child: row),
        ),
      ),
    );
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DitherSwitcher(collapse: true, child: empty),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('row')), findsNothing);
  });
}
