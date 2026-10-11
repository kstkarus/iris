import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/fold_row.dart';

import '../../helpers/test_app.dart';

void main() {
  Future<void> pumpList(WidgetTester tester, int count) {
    return tester.pumpWidget(
      testApp(
        Scaffold(
          body: FoldingList(
            items: [for (var index = 0; index < count; index++) 'item $index'],
            visible: 2,
            minFolded: 2,
            toggleKey: const Key('toggle'),
            builder: (context, shown) =>
                Column(children: [for (final item in shown) Text(item)]),
          ),
        ),
      ),
    );
  }

  testWidgets('folds the rest behind a toggle that unfolds it', (tester) async {
    await pumpList(tester, 4);

    expect(find.text('item 1'), findsOneWidget);
    expect(find.text('item 2'), findsNothing);

    await tester.tap(find.byKey(const Key('toggle')));
    await tester.pumpAndSettle();

    expect(find.text('item 3'), findsOneWidget);
  });

  testWidgets('shows everything when too few would be hidden', (tester) async {
    await pumpList(tester, 3);

    expect(find.text('item 2'), findsOneWidget);
    expect(find.byKey(const Key('toggle')), findsNothing);
  });
}
