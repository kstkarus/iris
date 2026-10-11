import 'package:flutter/material.dart';

import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

/// Shows or folds the rest of a list; a row of the list, so its label
/// starts where the rows' text does.
class FoldRow extends StatelessWidget {
  const FoldRow({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        // Ink paints on the nearest Material: this one scrolls with the row,
        // so the list's edge clips the highlight.
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
        ),
      ),
    );
  }
}

/// [items] built by [builder], folded after the first [visible] behind a
/// [FoldRow] when at least [minFolded] would be hidden. What is below
/// moves with the rows rather than jumping.
class FoldingList<T> extends StatefulWidget {
  const FoldingList({
    required this.items,
    required this.visible,
    required this.minFolded,
    required this.toggleKey,
    required this.builder,
    this.gapBeforeToggle = 0,
    super.key,
  });

  final List<T> items;
  final int visible;
  final int minFolded;
  final Key toggleKey;
  final double gapBeforeToggle;
  final Widget Function(BuildContext context, List<T> shown) builder;

  @override
  State<FoldingList<T>> createState() => _FoldingListState<T>();
}

class _FoldingListState<T> extends State<FoldingList<T>> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = widget.items;
    final hidden = items.length - widget.visible;
    final folds = hidden >= widget.minFolded;
    final shown = _expanded || !folds
        ? items
        : items.take(widget.visible).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: widget.builder(context, shown),
        ),
        if (folds) ...[
          if (widget.gapBeforeToggle > 0)
            SizedBox(height: widget.gapBeforeToggle),
          const SegmentedRule(),
          FoldRow(
            key: widget.toggleKey,
            label: _expanded
                ? l10n.commonShowLess
                : l10n.commonShowMore(hidden),
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
        ],
      ],
    );
  }
}
