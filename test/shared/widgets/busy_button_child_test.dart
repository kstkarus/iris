import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/app/theme/app_theme.dart';
import 'package:iris/shared/widgets/busy_button_child.dart';

void main() {
  for (final filled in [true, false]) {
    testWidgets(
      'a busy ${filled ? 'filled' : 'outlined'} button keeps its size and announces progress',
      (tester) async {
        const key = Key('submit');
        var presses = 0;

        Widget app({required bool busy}) {
          final label = BusyButtonChild(
            'Save',
            busy: busy,
            busyLabel: 'Saving changes',
          );
          final VoidCallback? onPressed = busy ? null : () => presses++;
          return MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: Center(
                child: filled
                    ? FilledButton(
                        key: key,
                        style: busyButtonStyle(busy: busy),
                        onPressed: onPressed,
                        child: label,
                      )
                    : OutlinedButton(
                        key: key,
                        style: busyButtonStyle(busy: busy),
                        onPressed: onPressed,
                        child: label,
                      ),
              ),
            ),
          );
        }

        await tester.pumpWidget(app(busy: false));
        final button = find.byKey(key);
        final idle = tester.getRect(button);
        await tester.tap(button);
        expect(presses, 1);

        await tester.pumpWidget(app(busy: true));
        expect(tester.getRect(button), idle);
        expect(
          tester.getSemantics(button),
          isSemantics(
            label: 'Saving changes',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            isLiveRegion: true,
          ),
        );
        await tester.tap(button);
        expect(presses, 1);
      },
    );
  }
}
