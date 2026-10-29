import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/presentation/widgets/player_auto_hiding_offer.dart';

void main() {
  const plate = SizedBox(key: Key('plate'), width: 200, height: 64);

  Future<void> pumpOffer(
    WidgetTester tester,
    ValueNotifier<bool> controls, {
    bool reducedMotion = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Center(
          child: PlayerAutoHidingOffer(controlsVisible: controls, child: plate),
        ),
      ),
    ),
  );

  double entranceOpacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find.ancestor(
          of: find.byKey(plate.key!),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;

  testWidgets('fades in on first appearance, without restarting when controls '
      'return', (tester) async {
    final controls = ValueNotifier(false);
    addTearDown(controls.dispose);
    await pumpOffer(tester, controls);
    expect(entranceOpacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 100));
    expect(entranceOpacity(tester), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(entranceOpacity(tester), 1);

    await tester.pump(PlayerAutoHidingOffer.shownAtStart);
    await tester.pump(const Duration(milliseconds: 200));
    final fade = find.ancestor(
      of: find.byKey(plate.key!),
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(fade).opacity, 0);
    controls.value = true;
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(fade).opacity, 1);
    expect(entranceOpacity(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appears immediately with reduced motion', (tester) async {
    final controls = ValueNotifier(false);
    addTearDown(controls.dispose);
    await pumpOffer(tester, controls, reducedMotion: true);
    expect(entranceOpacity(tester), 1);
    expect(tester.takeException(), isNull);
  });
}
