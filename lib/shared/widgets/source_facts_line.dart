import 'package:flutter/material.dart';

import 'package:iris/l10n/generated/app_localizations.dart';

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
    final facts = this.facts;
    return Text.rich(
      TextSpan(
        children: [
          if (watched) ...[
            TextSpan(
              text: l10n.watchSourceUsedBadge,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            if (facts != null) const TextSpan(text: ' · '),
          ],
          ?(facts == null ? null : TextSpan(text: facts)),
        ],
      ),
      style: theme.textTheme.bodySmall,
    );
  }
}
