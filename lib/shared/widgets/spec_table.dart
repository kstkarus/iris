import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/segmented_bar.dart';

class SpecRow {
  const SpecRow(this.label, this.value, {this.trailing});

  final String label;
  final String value;

  /// An action that belongs to this value, such as "Clear".
  final Widget? trailing;
}

/// Facts as label and value pairs, each row under a dashed rule.
class SpecTable extends StatelessWidget {
  const SpecTable({required this.rows, this.labelWidth = 120, super.key});

  final List<SpecRow> rows;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows) ...[
          SegmentedRule(color: theme.colorScheme.outlineVariant),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Row(
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(row.label, style: theme.textTheme.bodySmall),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(row.value, style: theme.textTheme.bodyMedium),
                  ),
                ),
                ?row.trailing,
              ],
            ),
          ),
        ],
      ],
    );
  }
}
