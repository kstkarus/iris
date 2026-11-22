import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/anime/domain/anime_kind.dart';
import 'package:iris/features/anime_details/domain/entities/related_anime.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/settings/presentation/anime_title_labels.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';
import 'package:iris/shared/utils/incomplete_date.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/fold_row.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';
import 'package:iris/shared/widgets/poster_image.dart';
import 'package:iris/shared/widgets/tap_row.dart';

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
  final shown = related.where((item) => !isPromoAnimeKind(item.anime.kind));
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
class RelatedAnimeSection extends StatelessWidget {
  const RelatedAnimeSection({required this.related, super.key});

  /// Rows shown before the rest folds away: long franchises list dozens
  /// of specials and recaps.
  static const visibleRows = 3;

  /// A toggle as tall as the one row it would hide saves nothing.
  static const _minFolded = 2;

  final List<RelatedAnime> related;

  @override
  Widget build(BuildContext context) {
    final related = relatedToShow(this.related);
    final Widget child;
    if (related.isEmpty) {
      child = const SizedBox.shrink(key: ValueKey('empty'));
    } else {
      final l10n = AppLocalizations.of(context);
      final scheme = Theme.of(context).colorScheme;
      final ruleColor = DetailLayout.ruleColor(scheme);
      child = Padding(
        key: const ValueKey('content'),
        padding: const EdgeInsets.only(top: 32),
        child: DetailSection(
          label: l10n.animeDetailsRelatedTitle,
          child: Container(
            color: scheme.surfaceContainerLow,
            foregroundDecoration: DetailLayout.cardDecoration(
              scheme,
              background: Colors.transparent,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: FoldingList(
                key: const Key('related_anime_section'),
                items: related,
                visible: visibleRows,
                minFolded: _minFolded,
                toggleKey: const Key('related_anime_more'),
                divider: Divider(height: 1, thickness: 1, color: ruleColor),
                builder: (context, shown) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, item) in shown.indexed) ...[
                      if (index > 0)
                        Divider(height: 1, thickness: 1, color: ruleColor),
                      _RelatedRow(related: item),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return DitherSwitcher(
      collapse: true,
      duration: const Duration(milliseconds: 240),
      resizeDuration: const Duration(milliseconds: 200),
      child: child,
    );
  }
}

/// Poster thumbnail, relation/kind/year caption, title, optional Russian title,
/// and navigation arrow.
class _RelatedRow extends StatelessWidget {
  const _RelatedRow({required this.related});

  final RelatedAnime related;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final anime = related.anime;
    final year = yearOfIsoDate(anime.airedOn)?.toString() ?? '';
    final captionParts = [
      formatAnimeRelation(l10n, related.relation),
      if (anime.kind.isNotEmpty) formatAnimeKind(l10n, anime.kind),
      if (year.isNotEmpty) year,
    ];
    final titles = watchAnimeTitleLabels(context, anime.titles);
    return TapRow(
      inkKey: ValueKey('related_anime_${anime.id}'),
      onTap: () => context.pushNamed(
        'anime-details',
        pathParameters: {'id': anime.id},
        extra: AnimeDetailsPreview.fromSummary(anime),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 40, child: PosterImage(url: anime.posterUrl)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PixelSeparatedText.parts(
                    captionParts,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    sansStyle: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: DetailLayout.sansFont,
                      color: muted,
                    ),
                    monoStyle: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: DetailLayout.monoFont,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    titles.primary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: DetailLayout.sansFont,
                    ),
                  ),
                  if (titles.secondary case final secondary?) ...[
                    const SizedBox(height: 2),
                    Text(
                      secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: DetailLayout.sansFont,
                        color: muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 12, right: 4),
              child: PixelIcon(PixelGlyph.arrowRight, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
