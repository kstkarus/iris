import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/search_field.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('animates prefix cancel button and suffix clear button', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var cancelled = 0;
    var lastQuery = '';
    var showCancel = false;

    Widget buildField({bool disableAnimations = false}) => testApp(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SearchField(
              controller: controller,
              hintText: 'Search',
              onChanged: (value) => lastQuery = value,
              onCancel: showCancel ? () => cancelled++ : null,
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildField());
    expect(find.byKey(SearchField.clearButtonKey), findsNothing);
    expect(find.byKey(SearchField.cancelButtonKey), findsNothing);

    await tester.enterText(find.byType(TextField), 'eva');
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(SearchField.clearButtonKey), findsOneWidget);

    await tester.tap(find.byKey(SearchField.clearButtonKey));
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
    expect(lastQuery, isEmpty);
    expect(find.byKey(SearchField.clearButtonKey), findsNothing);

    showCancel = true;
    await tester.pumpWidget(buildField());
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(SearchField.cancelButtonKey));
    expect(cancelled, 1);
  });

  testWidgets('switches icons immediately when animations are disabled', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      testApp(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SearchField(
              controller: controller,
              hintText: 'Search',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'eva');
    await tester.pump();
    expect(find.byKey(SearchField.clearButtonKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SearchField),
        matching: find.byType(AnimatedSwitcher),
      ),
      findsNothing,
    );
  });
}
