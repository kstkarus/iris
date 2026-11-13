import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';

void main() {
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
}
