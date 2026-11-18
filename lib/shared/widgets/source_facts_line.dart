import 'package:flutter/material.dart';

import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';

/// A source's facts in small type, led by the "watched" mark when the user
/// played from it before.
class SourceFactsLine extends StatelessWidget {
  const SourceFactsLine({
    required this.watched,
    this.facts,
    this.cleanLineWrap = false,
    super.key,
  });

  final bool watched;
  final String? facts;
  final bool cleanLineWrap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final base = theme.textTheme.bodySmall;
    final sansStyle = base?.copyWith(
      fontFamily: DetailLayout.sansFont,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final monoStyle = base?.copyWith(
      fontFamily: DetailLayout.monoFont,
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final spans = <InlineSpan>[
      if (watched)
        TextSpan(
          text: l10n.watchSourceUsedBadge,
          style: sansStyle?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      if (facts != null)
        for (final piece in PixelSeparatedText.splitSegments(facts!))
          DetailLayout.mixedDataSpan(
            piece,
            sansStyle: sansStyle,
            monoStyle: monoStyle,
          ),
    ];
    return PixelSeparatedText.spans(
      spans,
      style: sansStyle,
      cleanLineWrap: cleanLineWrap,
    );
  }
}
