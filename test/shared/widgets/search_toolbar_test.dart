import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/search_field.dart';
import 'package:iris/shared/widgets/search_toolbar.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('animates active marker and count badge across wide and narrow', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var taps = 0;

    Widget buildToolbar({
      required bool isWide,
      bool actionActive = false,
      int actionCount = 0,
      bool disableAnimations = false,
    }) => testApp(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: SearchToolbar(
            searchField: SearchField(
              controller: controller,
              hintText: 'Search',
              onChanged: (_) {},
            ),
            actionIcon: PixelGlyph.tune,
            actionLabel: 'Filters',
            onAction: () => taps++,
            isWide: isWide,
            actionActive: actionActive,
            actionCount: actionCount,
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildToolbar(isWide: false));
    expect(find.text('2'), findsNothing);

    await tester.pumpWidget(
      buildToolbar(isWide: false, actionActive: true, actionCount: 2),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    expect(taps, 1);

    await tester.pumpWidget(
      buildToolbar(isWide: false, actionActive: true, actionCount: 3),
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsNothing);

    await tester.pumpWidget(buildToolbar(isWide: true, actionActive: true));
    await tester.pumpAndSettle();
    final square = find.byKey(const ValueKey('active')).last;
    final action = find.text('Filters');
    double squareOffset() =>
        tester.getCenter(square).dy - tester.getCenter(action).dy;
    final restingOffset = squareOffset();

    await tester.pumpWidget(buildToolbar(isWide: true, actionCount: 3));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);

    await tester.pumpWidget(buildToolbar(isWide: true, actionActive: true));
    for (var frame = 0; frame < 18; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(squareOffset(), closeTo(restingOffset, 0.01));
    }
  });

  testWidgets('updates markers immediately when animations are disabled', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    Widget buildToolbar({int actionCount = 0}) => testApp(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: SearchToolbar(
            searchField: SearchField(
              controller: controller,
              hintText: 'Search',
              onChanged: (_) {},
            ),
            actionIcon: PixelGlyph.tune,
            actionLabel: 'Filters',
            onAction: () {},
            isWide: false,
            actionCount: actionCount,
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildToolbar());
    await tester.pumpWidget(buildToolbar(actionCount: 4));
    await tester.pump();

    expect(find.text('4'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
