import 'package:flutter/material.dart';

import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/fold_row.dart';
import 'package:iris/shared/widgets/labeled_section.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

/// The dub teams Shikimori knows of, as one run of names; a long run
/// folds after the first [visibleNames]. Nothing when there are none.
class DubsSection extends StatefulWidget {
  const DubsSection({required this.dubs, this.labelWidth, super.key});

  static const visibleNames = 12;

  /// Folding fewer than this would hide less than the fold row takes.
  static const _minFolded = 3;

  final List<String> dubs;

  /// Width of the label column; null puts the label above.
  final double? labelWidth;

  @override
  State<DubsSection> createState() => _DubsSectionState();
}

class _DubsSectionState extends State<DubsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final dubs = widget.dubs;
    if (dubs.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final hidden = dubs.length - DubsSection.visibleNames;
    final folds = hidden >= DubsSection._minFolded;
    final shown = _expanded || !folds
        ? dubs
        : dubs.take(DubsSection.visibleNames);
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: LabeledSection(
        label: l10n.animeDetailsDubsTitle,
        labelWidth: widget.labelWidth,
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AdaptiveContentWidth.reading,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSize(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: Text(
                    shown.join(' · '),
                    key: const Key('dubs_section_names'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (folds) ...[
                  const SizedBox(height: 12),
                  const SegmentedRule(),
                  FoldRow(
                    key: const Key('dubs_section_more'),
                    label: _expanded
                        ? l10n.commonShowLess
                        : l10n.commonShowMore(hidden),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
