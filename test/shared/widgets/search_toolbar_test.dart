import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/search_field.dart';
import 'package:iris/shared/widgets/search_toolbar.dart';

void main() {
  for (final isWide in [true, false]) {
    testWidgets('search field and action share one height '
        '(${isWide ? 'wide' : 'narrow'})', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
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
