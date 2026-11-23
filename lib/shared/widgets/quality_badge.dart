import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/detail_layout.dart';

/// A resolution, optionally qualified as "up to", in the app's compact frame.
class QualityBadge extends StatelessWidget {
  const QualityBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final style = theme.textTheme.labelSmall?.copyWith(letterSpacing: 0);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: MixedDataText(
            label,
            maxLines: 1,
            sansStyle: style?.copyWith(
              color: color,
              fontFamily: DetailLayout.sansFont,
            ),
            monoStyle: DetailLayout.monoTelemetryStyle(style, color: color),
          ),
        ),
      ),
    );
  }
}
