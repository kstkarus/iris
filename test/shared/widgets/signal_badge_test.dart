import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/utils/bayer_mask.dart';
import 'package:iris/shared/widgets/dither_transition.dart';
import 'package:iris/shared/widgets/signal_badge.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets(
    'animates dot in and out via BayerMasked even when dotKey is set',
    (tester) async {
      const dotKey = Key('signal_dot');
      final visible = ValueNotifier(false);
      addTearDown(visible.dispose);

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: visible,
                builder: (context, shown, _) => SignalBadge(
                  visible: shown,
                  dotKey: dotKey,
                  child: const Text('Downloads'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(dotKey), findsNothing);

      visible.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.byKey(dotKey), findsOneWidget);
      final appearing = tester.widget<BayerMasked>(find.byType(BayerMasked));
      expect(appearing.open, greaterThan(0));
      expect(appearing.open, lessThan(BayerMask.steps));

      await tester.pumpAndSettle();
      expect(
        tester.widget<BayerMasked>(find.byType(BayerMasked)).open,
        BayerMask.steps,
      );

      visible.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.byKey(dotKey), findsNothing);
      final disappearing = tester.widget<BayerMasked>(find.byType(BayerMasked));
      expect(disappearing.open, greaterThan(0));
      expect(disappearing.open, lessThan(BayerMask.steps));

      await tester.pumpAndSettle();
      expect(tester.widget<BayerMasked>(find.byType(BayerMasked)).open, 0);
    },
  );

  testWidgets('skips animation under reduced motion', (tester) async {
    const dotKey = Key('signal_dot');
    final visible = ValueNotifier(false);
    addTearDown(visible.dispose);

    await tester.pumpWidget(
      testApp(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: visible,
                builder: (context, shown, _) => SignalBadge(
                  visible: shown,
                  dotKey: dotKey,
                  child: const Text('Downloads'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    visible.value = true;
    await tester.pump();
    expect(find.byKey(dotKey), findsOneWidget);
    expect(find.byType(BayerMasked), findsNothing);

    visible.value = false;
    await tester.pump();
    expect(find.byKey(dotKey), findsNothing);
  });
}
