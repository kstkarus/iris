import 'package:flutter/material.dart';

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
