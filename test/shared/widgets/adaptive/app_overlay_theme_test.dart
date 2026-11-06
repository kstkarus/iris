import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/app/theme/app_theme.dart';
import 'package:iris/shared/widgets/adaptive/show_adaptive_sheet.dart';
import 'package:iris/shared/widgets/adaptive/show_app_dialog.dart';

import '../../../helpers/test_app.dart';
import '../../../helpers/test_window.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final presentation in ['dialog', 'phone sheet', 'desktop sheet']) {
      testWidgets(
        '$presentation inverts $brightness without changing its page',
        (tester) async {
          setTestWindowSize(
            tester,
            presentation == 'phone sheet'
                ? const Size(390, 844)
                : const Size(1200, 900),
          );
          Brightness? overlay;
          Widget content(BuildContext context) {
            overlay = Theme.of(context).brightness;
            return TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('close'),
            );
          }

          await tester.pumpWidget(
            testApp(
              Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () {
                      if (presentation == 'dialog') {
                        showAppDialog<void>(
                          context: context,
                          builder: (context) =>
                              AlertDialog(content: content(context)),
                        );
                      } else {
                        showAdaptiveSheet<void>(
                          context: context,
                          builder: content,
                        );
                      }
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
              theme: buildAppTheme(brightness: brightness),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(
            overlay,
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          );
          await tester.tap(find.text('close'));
          await tester.pumpAndSettle();
          expect(
            Theme.of(tester.element(find.text('open'))).brightness,
            brightness,
          );
        },
      );
    }
  }
}
