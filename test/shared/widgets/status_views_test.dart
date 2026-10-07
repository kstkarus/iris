import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/status_views.dart';

void main() {
  testWidgets('the block spinner draws blocks of its full height', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(width: 120, child: BlockSpinner(height: 10)),
        ),
      ),
    );

    final blocks = find.descendant(
      of: find.byType(BlockSpinner),
      matching: find.byType(ColoredBox),
    );
    expect(blocks, findsNWidgets(12));
    for (final block in blocks.evaluate()) {
      expect((block.renderObject! as RenderBox).size.height, 10);
    }
  });
}
