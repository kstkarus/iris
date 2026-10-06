import 'package:flutter/widgets.dart';

/// Number of equally sized columns that fit into [availableWidth] when each
/// column needs at least [minItemWidth].
int adaptiveColumnCount({
  required double availableWidth,
  required double minItemWidth,
  double spacing = 16,
  int maxColumns = 4,
}) {
  if (!availableWidth.isFinite || availableWidth <= 0) {
    return 1;
  }

  final columns = ((availableWidth + spacing) / (minItemWidth + spacing))
      .floor();
  return columns.clamp(1, maxColumns);
}

/// One row of an adaptive card grid.
///
/// Cards in the same row share the tallest card's height, so content of any
/// length never overflows a fixed tile extent. Missing trailing cells are left
/// empty to keep column widths stable.
class AdaptiveGridRow extends StatelessWidget {
  const AdaptiveGridRow({
    required this.columns,
    required this.children,
    this.spacing = 16,
    super.key,
  }) : assert(columns > 0);

  final int columns;
  final double spacing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    assert(children.length <= columns, 'More children than columns.');
    if (columns == 1 && children.length == 1) {
      return children.single;
    }

    final cells = <Widget>[];
    for (var index = 0; index < columns; index++) {
      if (index > 0) {
        cells.add(SizedBox(width: spacing));
      }
      cells.add(
        Expanded(
          child: index < children.length
              ? children[index]
              : const SizedBox.shrink(),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cells,
      ),
    );
  }
}
