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
    await tester.pump();
    expect(outline(), isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    expect(deletes, 1);
  });
}
