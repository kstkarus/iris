import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/features/anime_details/domain/entities/related_anime.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';
import 'package:iris/shared/utils/incomplete_date.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/fold_row.dart';
import 'package:iris/shared/widgets/labeled_section.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';

/// Commercials, promo videos and music clips: listed by Shikimori, but
/// nothing to watch.
const _promoKinds = {'cm', 'pv', 'music'};

/// What comes before and after first, then the rest of the franchise from
/// the closest kin outwards.
const _relationOrder = [
  AnimeRelation.prequel,
  AnimeRelation.sequel,
  AnimeRelation.parentStory,
  AnimeRelation.fullStory,
  AnimeRelation.sideStory,
  AnimeRelation.alternativeSetting,
  AnimeRelation.alternativeVersion,
  AnimeRelation.spinOff,
  AnimeRelation.summary,
  AnimeRelation.character,
  AnimeRelation.other,
];

/// The related anime worth listing, in the order they are listed: by
/// relation, then by air date, undated last.
List<RelatedAnime> relatedToShow(List<RelatedAnime> related) {
  final shown = related.where((item) => !_promoKinds.contains(item.anime.kind));
  return shown.toList()..sort((a, b) {
    final byRelation = _relationOrder
        .indexOf(a.relation)
        .compareTo(_relationOrder.indexOf(b.relation));
    if (byRelation != 0) return byRelation;
    final aAiredOn = a.anime.airedOn;
    final bAiredOn = b.anime.airedOn;
    if (aAiredOn.isEmpty != bAiredOn.isEmpty) {
      return aAiredOn.isEmpty ? 1 : -1;
    }
    return aAiredOn.compareTo(bAiredOn);
  });
}

String formatAnimeRelation(AppLocalizations l10n, AnimeRelation relation) =>
    switch (relation) {
      AnimeRelation.prequel => l10n.animeRelationPrequel,
      AnimeRelation.sequel => l10n.animeRelationSequel,
      AnimeRelation.parentStory => l10n.animeRelationParentStory,
      AnimeRelation.fullStory => l10n.animeRelationFullStory,
      AnimeRelation.sideStory => l10n.animeRelationSideStory,
      AnimeRelation.alternativeSetting => l10n.animeRelationAlternativeSetting,
      AnimeRelation.alternativeVersion => l10n.animeRelationAlternativeVersion,
      AnimeRelation.spinOff => l10n.animeRelationSpinOff,
      AnimeRelation.summary => l10n.animeRelationSummary,
      AnimeRelation.character => l10n.animeRelationCharacter,
      AnimeRelation.other => l10n.animeRelationOther,
    };

/// The rest of the franchise, each title a row that opens its page.
class RelatedAnimeSection extends StatefulWidget {
  const RelatedAnimeSection({
    required this.related,
    this.labelWidth,
    super.key,
  });

  /// Rows shown before the rest folds away: long franchises list dozens
  /// of specials and recaps.
  static const visibleRows = 3;

  /// A toggle as tall as the one row it would hide saves nothing.
  static const _minFolded = 2;

  final List<RelatedAnime> related;

  /// Width of the label column; null puts the label above the rows.
  final double? labelWidth;

  @override
  State<RelatedAnimeSection> createState() => _RelatedAnimeSectionState();
}

class _RelatedAnimeSectionState extends State<RelatedAnimeSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final related = relatedToShow(widget.related);
    // It may well be empty, so no noise for it: it develops in when
    // it arrives, below everything it could push.
    if (related.isEmpty) return const DitherSwitcher(child: SizedBox.shrink());

    final l10n = AppLocalizations.of(context);
    final hidden = related.length - RelatedAnimeSection.visibleRows;
    final folds = hidden >= RelatedAnimeSection._minFolded;
    final shown = _expanded || !folds
        ? related
        : related.take(RelatedAnimeSection.visibleRows).toList();
    return DitherSwitcher(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: LabeledSection(
          label: l10n.animeDetailsRelatedTitle,
          labelWidth: widget.labelWidth,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AdaptiveContentWidth.reading,
              ),
              child: Column(
                key: const Key('related_anime_section'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedSize(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, item) in shown.indexed) ...[
                          if (index > 0) const SegmentedRule(),
                          _RelatedRow(related: item, first: index == 0),
                        ],
                      ],
                    ),
                  ),
                  if (folds) ...[
                    const SegmentedRule(),
                    FoldRow(
                      key: const Key('related_anime_more'),
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
      ),
    );
  }
}

/// The relation, kind and year over the title, as the row's caption;
/// the Russian title under it when it says something else.
class _RelatedRow extends StatelessWidget {
  const _RelatedRow({required this.related, required this.first});

  final RelatedAnime related;

  /// The first row starts level with the section label.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final anime = related.anime;
    final year = yearOfIsoDate(anime.airedOn)?.toString() ?? '';
    final caption = [
      formatAnimeRelation(l10n, related.relation),
      if (anime.kind.isNotEmpty) formatAnimeKind(l10n, anime.kind),
      if (year.isNotEmpty) year,
    ].join(' · ');
    final russian = anime.russian.trim();
    return Material(
      // Ink paints on the nearest Material: this one scrolls with the row,
      // so the list's edge clips the highlight.
      type: MaterialType.transparency,
      child: InkWell(
        key: ValueKey('related_anime_${anime.id}'),
        onTap: () => context.pushNamed(
          'anime-details',
          pathParameters: {'id': anime.id},
          extra: AnimeDetailsPreview.fromSummary(anime),
        ),
        child: Padding(
          padding: EdgeInsets.only(top: first ? 0 : 12, bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      anime.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (russian.isNotEmpty &&
                        russian.toLowerCase() != anime.name.toLowerCase()) ...[
                      const SizedBox(height: 2),
                      Text(
                        russian,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 16, right: 8),
                child: PixelIcon(PixelGlyph.arrowRight, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
