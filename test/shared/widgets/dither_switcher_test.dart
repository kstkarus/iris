import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/dither_transition.dart';

void main() {
  Future<void> pumpSwitcher(
    WidgetTester tester, {
    required Widget child,
    bool collapse = false,
    Duration? reverseDuration,
  }) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: DitherSwitcher(
          key: const ValueKey('switcher'),
          collapse: collapse,
          reverseDuration: reverseDuration,
          child: child,
        ),
      ),
    ),
  );

  double height(WidgetTester tester) =>
      tester.getSize(find.byKey(const ValueKey('switcher'))).height;

  const empty = SizedBox(key: ValueKey('empty'), width: 100);
  const row = SizedBox(key: ValueKey('row'), width: 100, height: 60);

  testWidgets('a horizontal reveal grows from the leading edge', (
    tester,
  ) async {
    const revealKey = ValueKey('reveal');
    final reveal = find.byKey(revealKey);
    for (final direction in TextDirection.values) {
      for (final progress in [0.5, 1.0, 0.5, 0.0]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: direction,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox(
                key: revealKey,
                child: DitherTransition.horizontalReveal(row, progress),
              ),
            ),
          ),
        );

        final visible = tester.getRect(reveal);
        final full = tester.getRect(find.byKey(row.key!));
        expect(visible.width, full.width * progress);
        expect(
          direction == TextDirection.ltr ? visible.left : visible.right,
          direction == TextDirection.ltr ? full.left : full.right,
        );
      }
    }
  });

  testWidgets('a shorter reverse duration keeps both collapse stages', (
    tester,
  ) async {
    const reverse = Duration(milliseconds: 320);
    await pumpSwitcher(
      tester,
      collapse: true,
      reverseDuration: reverse,
      child: row,
    );
    await pumpSwitcher(
      tester,
      collapse: true,
      reverseDuration: reverse,
      child: empty,
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(height(tester), 60);
    await tester.pump(const Duration(milliseconds: 100));
    expect(height(tester), inExclusiveRange(0, 60));
    await tester.pump(const Duration(milliseconds: 71));
    await tester.pump();
    expect(height(tester), 0);
    expect(find.byKey(const ValueKey('row')), findsNothing);
  });

  for (final collapse in [false, true]) {
    testWidgets('outgoing controls cannot be pressed (collapse: $collapse)', (
      tester,
    ) async {
      var taps = 0;
      await pumpSwitcher(
        tester,
        collapse: collapse,
        child: GestureDetector(
          key: const ValueKey('button'),
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: const SizedBox(width: 100, height: 60),
        ),
      );
      await pumpSwitcher(tester, collapse: collapse, child: empty);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(const Offset(20, 20));
      expect(taps, 0);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('a leaving control loses keyboard and screen reader access', (
    tester,
  ) async {
    final current = ValueNotifier(false);
    final oldFocus = FocusNode();
    final newFocus = FocusNode();
    addTearDown(current.dispose);
    addTearDown(oldFocus.dispose);
    addTearDown(newFocus.dispose);
    var oldPresses = 0;
    var newPresses = 0;
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: current,
              builder: (context, changed, _) => DitherSwitcher(
                child: FilledButton(
                  key: ValueKey(changed),
                  focusNode: changed ? newFocus : oldFocus,
                  onPressed: changed ? () => newPresses++ : () => oldPresses++,
                  child: Text(changed ? 'New action' : 'Old action'),
                ),
              ),
            ),
          ),
        ),
      );
      oldFocus.requestFocus();
      await tester.pump();
      expect(oldFocus.hasPrimaryFocus, isTrue);
      expect(find.semantics.byLabel('Old action'), findsOne);

      current.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('Old action'), findsOneWidget);
      expect(find.semantics.byLabel('Old action'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(oldPresses, 0);

      newFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(newPresses, 1);
      await tester.pumpAndSettle();
    } finally {
      semantics.dispose();
    }
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
          child: DitherSwitcher(
            collapse: true,
            reverseDuration: Duration(milliseconds: 320),
            child: row,
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DitherSwitcher(
            collapse: true,
            reverseDuration: Duration(milliseconds: 320),
            child: empty,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('row')), findsNothing);
  });
}
