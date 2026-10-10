import 'dart:math' as math;

/// Space between the columns of a list laid out in a grid.
const gridGap = 24.0;

/// How many columns of at least [minWidth] fit in [width]: one on a phone,
/// more where a single column would stretch rows across the window.
int gridColumns(double width, {required double minWidth}) =>
    math.max(1, ((width + gridGap) / (minWidth + gridGap)).floor());
