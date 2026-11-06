import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/search_field.dart';
import 'package:iris/shared/widgets/search_toolbar.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('filter count sits beyond the button and clears the glyph', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: SearchToolbar(
              searchField: SearchField(
                controller: controller,
                hintText: 'Search',
                onChanged: (_) {},
              ),
              actionIcon: PixelGlyph.tune,
              actionLabel: 'Filters',
              actionCount: 12,
              onAction: () {},
              isWide: false,
            ),
          ),
        ),
      ),
    );
    final button = tester.getRect(find.byTooltip('Filters'));
    final badge = tester.getRect(find.text('12'));
    final icon = tester.getRect(find.byType(PixelIcon).last);
    expect(badge.top, lessThan(button.top));
    expect(badge.right, greaterThan(button.right));
    expect(badge.overlaps(icon), isFalse);
  });

  for (final isWide in [true, false]) {
    testWidgets('search field and action share one height '
        '(${isWide ? 'wide' : 'narrow'})', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: SearchToolbar(
              searchField: SearchField(
                controller: controller,
                hintText: 'Search',
                onChanged: (_) {},
              ),
              actionIcon: PixelGlyph.sort,
              actionLabel: 'Sort',
              onAction: () {},
              isWide: isWide,
            ),
          ),
        ),
      );

      final fieldHeight = tester.getSize(find.byType(TextField)).height;
      // Narrow toolbars show the action as an icon named by its tooltip.
      final actionHeight = tester
          .getSize(
            isWide
                ? find.widgetWithText(OutlinedButton, 'Sort')
                : find.byTooltip('Sort'),
          )
          .height;
      expect(fieldHeight, SearchField.height);
      expect(actionHeight, SearchField.height);
    });
  }
}
