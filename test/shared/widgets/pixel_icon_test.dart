import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

void main() {
  Future<Size> iconSize(WidgetTester tester, PixelGlyph glyph) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: PixelIcon(glyph, size: 21, color: Colors.black)),
      ),
    );
    return tester.getSize(find.byType(PixelIcon));
  }

  testWidgets('an icon glyph is square', (tester) async {
    expect(await iconSize(tester, PixelGlyph.check), const Size(21, 21));
  });

  testWidgets('a wide glyph keeps its proportions at the given height', (
    tester,
  ) async {
    expect(await iconSize(tester, PixelGlyph.eye), const Size(33, 21));
  });
}
