import 'package:flutter/material.dart';

/// A small upper-case caption: `labelSmall`, muted unless given a [color].
class CaptionText extends StatelessWidget {
  const CaptionText(this.text, {this.color, this.tabular = false, super.key});

  final String text;
  final Color? color;

  /// Figures of one width, so numbers line up from row to row.
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: color ?? theme.colorScheme.onSurfaceVariant,
        fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      ),
    );
  }
}
