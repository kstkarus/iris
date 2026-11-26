import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/dither_scroll_edge.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('paints dither edge only after scrolling away from top', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SizedBox(
            height: 200,
            child: DitherScrollEdge(
              child: ListView.builder(
                controller: controller,
                itemCount: 30,
                itemExtent: 40,
                itemBuilder: (_, index) => Text('Row $index'),
              ),
            ),
          ),
        ),
      ),
    );

    final edgeFinder = find.descendant(
      of: find.byType(DitherScrollEdge),
      matching: find.byType(CustomPaint),
    );
    expect(edgeFinder, findsNothing);

    controller.jumpTo(40);
    await tester.pump();
    expect(edgeFinder, findsOneWidget);

    controller.jumpTo(0);
    await tester.pump();
    expect(edgeFinder, findsNothing);
  });
}
