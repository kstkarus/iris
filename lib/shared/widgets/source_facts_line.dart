import 'package:flutter/material.dart';

import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';

/// A source's facts in small type, led by the "watched" mark when the user
/// played from it before.
class SourceFactsLine extends StatelessWidget {
  const SourceFactsLine({required this.watched, this.facts, super.key});

  final bool watched;
  final String? facts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final spans = <InlineSpan>[
      if (watched)
        TextSpan(
          text: l10n.watchSourceUsedBadge,
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
      if (facts != null)
        for (final piece in PixelSeparatedText.splitSegments(facts!))
          TextSpan(text: piece),
    ];
    return PixelSeparatedText.spans(spans, style: theme.textTheme.bodySmall);
  }
}
