import 'package:flutter/material.dart';

import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/fold_row.dart';
import 'package:iris/shared/widgets/labeled_section.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';

/// The dub teams Shikimori knows of, as one run of names; a long run
/// folds after the first [visibleNames]. Nothing when there are none.
class DubsSection extends StatelessWidget {
  const DubsSection({required this.dubs, this.labelWidth, super.key});

  static const visibleNames = 12;

  /// Folding fewer than this would hide less than the fold row takes.
  static const _minFolded = 3;

  final List<String> dubs;

  /// Width of the label column; null puts the label above.
  final double? labelWidth;

  @override
  Widget build(BuildContext context) {
    // It may well be empty, so no noise for it: it develops in when
    // it arrives, below everything it could push.
    if (dubs.isEmpty) return const DitherSwitcher(child: SizedBox.shrink());
    final l10n = AppLocalizations.of(context);
    return DitherSwitcher(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: LabeledSection(
          label: l10n.animeDetailsDubsTitle,
          labelWidth: labelWidth,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AdaptiveContentWidth.reading,
              ),
              child: FoldingList(
                items: dubs,
                visible: visibleNames,
                minFolded: _minFolded,
                toggleKey: const Key('dubs_section_more'),
                gapBeforeToggle: 12,
                builder: (context, shown) => Text(
                  shown.join(' · '),
                  key: const Key('dubs_section_names'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
