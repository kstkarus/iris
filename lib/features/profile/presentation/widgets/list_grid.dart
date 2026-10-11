import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';

/// Space between the columns of a list laid out in a grid.
const gridGap = 24.0;

/// How many columns of at least [minWidth] fit in [width]: one on a phone,
/// more where a single column would stretch rows across the window, with no
/// upper limit.
int gridColumns(double width, {required double minWidth}) =>
    adaptiveColumnCount(
      availableWidth: width,
      minItemWidth: minWidth,
      spacing: gridGap,
      maxColumns: 1 << 20,
    );
