import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/dither_transition.dart';

Widget _app(bool enabled, {bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: AppSkeleton(
          enabled: enabled,
          semanticLabel: 'Loading',
          child: Text(enabled ? 'Stand-in' : 'Real'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('screen readers hear the label, not the stand-in', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(true));

    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    expect(find.bySemanticsLabel('Stand-in'), findsNothing);

    semantics.dispose();
  });

  testWidgets('the content develops out of the noise', (tester) async {
    await tester.pumpWidget(_app(true));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pumpWidget(_app(false));
    await tester.pump(DitherTransition.duration ~/ 2);
    expect(find.text('Stand-in'), findsOneWidget, reason: 'still leaving');
    expect(find.text('Real'), findsOneWidget);

    await tester.pump(DitherTransition.duration);
    expect(find.text('Stand-in'), findsNothing);
    expect(find.text('Real'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('swaps at once when animations are off', (tester) async {
    await tester.pumpWidget(_app(true, disableAnimations: true));
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(_app(false, disableAnimations: true));
    expect(find.text('Stand-in'), findsNothing);
    expect(find.text('Real'), findsOneWidget);
  });
}
