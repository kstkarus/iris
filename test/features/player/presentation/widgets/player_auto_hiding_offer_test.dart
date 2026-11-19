import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/presentation/widgets/player_auto_hiding_offer.dart';
import 'package:iris/shared/utils/bayer_mask.dart';
import 'package:iris/shared/widgets/dither_transition.dart';

void main() {
  const plate = SizedBox(key: Key('plate'), width: 200, height: 64);

  Future<void> pumpOffer(
    WidgetTester tester,
    ValueNotifier<bool> controls, {
    bool reducedMotion = false,
    Widget child = plate,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Center(
          child: PlayerAutoHidingOffer(controlsVisible: controls, child: child),
        ),
      ),
    ),
  );

  int revealedCells(WidgetTester tester) => tester
      .widget<BayerMasked>(
        find.ancestor(
          of: find.byKey(plate.key!),
          matching: find.byType(BayerMasked),
        ),
      )
      .open;

  testWidgets('reveals once, without restarting when controls '
      'return', (tester) async {
    final controls = ValueNotifier(false);
    final focus = FocusNode();
    addTearDown(controls.dispose);
    addTearDown(focus.dispose);
    await pumpOffer(
      tester,
      controls,
      child: TextButton(
        key: plate.key,
        focusNode: focus,
        onPressed: () {},
        child: const Text('Skip opening'),
      ),
    );
    expect(revealedCells(tester), 0);

    await tester.pump(const Duration(milliseconds: 150));
    expect(revealedCells(tester), inExclusiveRange(0, BayerMask.steps));
    await tester.pump(const Duration(milliseconds: 150));
    expect(revealedCells(tester), BayerMask.steps);

    await tester.pump(PlayerAutoHidingOffer.shownAtStart);
    await tester.pump(const Duration(milliseconds: 200));
    final fade = find.ancestor(
      of: find.byKey(plate.key!),
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(fade).opacity, 0);
    expect(focus.canRequestFocus, isFalse);
    controls.value = true;
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(fade).opacity, 1);
    expect(revealedCells(tester), BayerMask.steps);
    expect(focus.canRequestFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appears immediately with reduced motion', (tester) async {
    final controls = ValueNotifier(false);
    addTearDown(controls.dispose);
    await pumpOffer(tester, controls, reducedMotion: true);
    expect(revealedCells(tester), BayerMask.steps);
    expect(tester.takeException(), isNull);
  });
}
