import 'package:flutter/material.dart';

/// A section heading in terminal shorthand: `>> LABEL`, small and upper
/// case, with an optional [trailing] action at the end of the row.
///
/// It carries no rule of its own: the rows below it bring theirs.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall;
    final trailing = this.trailing;
    return Semantics(
      header: true,
      child: Row(
        children: [
          ExcludeSemantics(
            child: Text(
              '>> ',
              style: style?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(text.toUpperCase(), style: style)),
          ?trailing,
        ],
      ),
    );
  }
}
