import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

void main() {
  group('WindowSizeClass.fromWidth', () {
    test('maps Material 3 breakpoints', () {
      expect(WindowSizeClass.fromWidth(390), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(599.9), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(600), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(839), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(840), WindowSizeClass.expanded);
      expect(WindowSizeClass.fromWidth(1199), WindowSizeClass.expanded);
      expect(WindowSizeClass.fromWidth(1200), WindowSizeClass.large);
      expect(WindowSizeClass.fromWidth(1599), WindowSizeClass.large);
      expect(WindowSizeClass.fromWidth(1600), WindowSizeClass.extraLarge);
    });

    test('compares size classes and exposes page margins', () {
      expect(WindowSizeClass.large.isAtLeast(WindowSizeClass.expanded), isTrue);
      expect(
        WindowSizeClass.medium.isAtLeast(WindowSizeClass.expanded),
        isFalse,
      );
      expect(WindowSizeClass.compact.pageMargin, 16);
      expect(WindowSizeClass.expanded.pageMargin, 24);
    });
  });

  group('adaptiveColumnCount', () {
    test('fits as many minimum-width columns as possible', () {
      expect(adaptiveColumnCount(availableWidth: 358, minItemWidth: 320), 1);
      expect(adaptiveColumnCount(availableWidth: 896, minItemWidth: 320), 2);
      expect(adaptiveColumnCount(availableWidth: 1600, minItemWidth: 320), 4);
    });

    test('respects the column cap and degenerate widths', () {
      expect(
        adaptiveColumnCount(
          availableWidth: 3000,
          minItemWidth: 320,
          maxColumns: 3,
        ),
        3,
      );
      expect(adaptiveColumnCount(availableWidth: 0, minItemWidth: 320), 1);
      expect(
        adaptiveColumnCount(availableWidth: double.infinity, minItemWidth: 320),
        1,
      );
    });
  });

  testWidgets('AdaptiveGridRow gives cards in a row the same height', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            child: AdaptiveGridRow(
              columns: 3,
              children: [
                SizedBox(key: Key('short'), height: 40),
                SizedBox(key: Key('tall'), height: 120),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('short'))).height, 120);
    expect(tester.getSize(find.byKey(const Key('tall'))).height, 120);
    expect(
      tester.getSize(find.byKey(const Key('short'))).width,
      closeTo((600 - 32) / 3, 0.001),
    );
  });
}
