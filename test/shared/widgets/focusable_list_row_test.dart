import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/focusable_list_row.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('keyboard focus shows as an outline; Delete deletes', (
    tester,
  ) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    var deletes = 0;
    await tester.pumpWidget(
      testApp(
        Material(
          child: FocusableListRow(
            onDelete: () => deletes++,
            onTap: () {},
            child: const Text('Row'),
          ),
        ),
      ),
    );
    BoxBorder? outline() {
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(FocusableListRow),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      return (box.decoration as BoxDecoration).border;
    }

    expect(outline(), isNull);

    Focus.of(tester.element(find.text('Row'))).requestFocus();
    await tester.pumpAndSettle();
    expect(outline(), isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    expect(deletes, 1);
  });

  testWidgets('animates filled state and honors reduced motion', (
    tester,
  ) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );

    Widget buildRow({required bool filled, bool disableAnimations = false}) =>
        testApp(
          MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: Material(
              child: FocusableListRow(
                filled: filled,
                onDelete: () {},
                onTap: () {},
                child: const Text('Row'),
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildRow(filled: false));
    await tester.pumpWidget(buildRow(filled: true));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(buildRow(filled: false, disableAnimations: true));
    await tester.pumpWidget(buildRow(filled: true, disableAnimations: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);

    Focus.of(tester.element(find.text('Row'))).requestFocus();
    await tester.pump();
    await tester.pump();
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(FocusableListRow),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((box.decoration as BoxDecoration).border, isNotNull);
  });
}
