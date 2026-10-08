import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/status_views.dart';

Widget _spinner({bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: const Center(
        child: SizedBox(width: 120, child: BlockSpinner(height: 10)),
      ),
    ),
  );
}

/// The colour of each block, left to right.
List<Color> _blockColors(WidgetTester tester) {
  final blocks = find.descendant(
    of: find.byType(BlockSpinner),
    matching: find.byType(ColoredBox),
  );
  return [
    for (final block in blocks.evaluate()) (block.widget as ColoredBox).color,
  ];
}

void main() {
  testWidgets('the block spinner draws blocks of its full height', (
    tester,
  ) async {
    await tester.pumpWidget(_spinner());

    final blocks = find.descendant(
      of: find.byType(BlockSpinner),
      matching: find.byType(ColoredBox),
    );
    expect(blocks, findsNWidgets(12));
    for (final block in blocks.evaluate()) {
      expect((block.renderObject! as RenderBox).size.height, 10);
    }
  });

  testWidgets('the block spinner sweeps while motion is allowed', (
    tester,
  ) async {
    await tester.pumpWidget(_spinner());

    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('the block spinner holds one frame when motion is reduced', (
    tester,
  ) async {
    await tester.pumpWidget(_spinner(disableAnimations: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);

    final frame = _blockColors(tester);
    expect(
      frame.where((color) => color != frame.first),
      hasLength(3),
      reason: 'a run of lit blocks',
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(_blockColors(tester), frame);

    await tester.pumpWidget(_spinner());
    expect(tester.hasRunningAnimations, isTrue);
  });
}
