import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/adaptive/page_frame.dart';

void main() {
  Future<Rect> childRect(WidgetTester tester, Widget frame, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: frame));
    return tester.getRect(find.byKey(const Key('content')));
  }

  const content = SizedBox.expand(key: Key('content'));

  testWidgets('a top-level page sits under the size class gap', (tester) async {
    final rect = await childRect(
      tester,
      const PageFrame(child: content),
      const Size(390, 800),
    );

    expect(rect.topLeft, const Offset(16, 12));
    expect(rect.width, 390 - 32);
  });

  testWidgets('a sub-page sits a fixed gap under its bar', (tester) async {
    final rect = await childRect(
      tester,
      const PageFrame.subPage(child: content),
      const Size(1000, 800),
    );

    expect(rect.topLeft, const Offset(24, 24));
  });

  testWidgets('a wide window centres the capped content', (tester) async {
    final rect = await childRect(
      tester,
      const PageFrame(child: content),
      const Size(2000, 800),
    );

    expect(rect.width, 1600);
    expect(rect.left, 200);
    expect(rect.top, 28);
  });
}
