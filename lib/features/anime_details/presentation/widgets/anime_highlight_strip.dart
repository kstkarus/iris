import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_passport.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';

/// High-signal metric strip and genre line shown right beneath the title on
/// wide desktop screens.
class AnimeHighlightStrip extends StatelessWidget {
  const AnimeHighlightStrip({
    required this.head,
    required this.loading,
    super.key,
  });

  final AnimeDetailsPreview head;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ruleColor = DetailLayout.ruleColor(scheme);
    final episodes = formatAnimeEpisodesValue(l10n, head);
    final nextEpisode = nextEpisodePassportEntry(l10n, head, loading: loading);
    final genresValue = animeGenresLineValue(l10n, head, loading: loading);

    final metricCards = <PassportEntry>[
      if (head.anime.score > 0)
        PassportEntry(
          label: l10n.animeDetailsFactScore,
          value: formatAnimeScoreValue(l10n, head.anime.score),
          emphasize: true,
          isData: true,
        ),
      if (episodes != null)
        PassportEntry(
          label: l10n.animeDetailsFactEpisodes,
          value: episodes,
          emphasize: true,
          isData: true,
        ),
      ?nextEpisode,
    ];

    if (metricCards.isEmpty && genresValue == null) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const Key('anime_details_more_facts'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (metricCards.isNotEmpty)
          DecoratedBox(
            decoration: DetailLayout.cardDecoration(scheme),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stack =
                    DetailLayout.isLargeText(context) ||
                    constraints.maxWidth < 420;
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, item) in metricCards.indexed) ...[
                        if (index > 0)
                          Divider(height: 1, thickness: 1, color: ruleColor),
                        _MetricTile(entry: item, loading: loading),
                      ],
                    ],
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, item) in metricCards.indexed) ...[
                        if (index > 0)
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: ruleColor,
                          ),
                        Expanded(
                          flex: item.isAnnouncement ? 2 : 1,
                          child: _MetricTile(
                            entry: item,
                            loading: loading,
                            alignBaseline: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        if (genresValue != null) ...[
          SizedBox(height: metricCards.isNotEmpty ? 12 : 0),
          _GenresLine(
            label: l10n.animeDetailsFactGenres,
            value: genresValue,
            loading: loading,
          ),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.entry,
    required this.loading,
    this.alignBaseline = false,
  });

  final PassportEntry entry;
  final bool loading;
  final bool alignBaseline;

  static double _alphabeticBaseline(
    InlineSpan span,
    TextScaler textScaler,
    TextDirection textDirection,
  ) {
    final painter = TextPainter(
      text: span,
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final distance = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    painter.dispose();
    return distance;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final emphasizedMonoStyle = theme.textTheme.headlineSmall?.copyWith(
      fontFamily: DetailLayout.monoFont,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w600,
    );
    final emphasizedSansStyle = theme.textTheme.headlineSmall?.copyWith(
      fontFamily: DetailLayout.sansFont,
      fontWeight: FontWeight.w500,
    );

    final sansStyle = entry.emphasize
        ? emphasizedSansStyle
        : theme.textTheme.titleMedium?.copyWith(
            fontFamily: DetailLayout.sansFont,
            fontWeight: FontWeight.w400,
          );
    final monoStyle = entry.emphasize
        ? emphasizedMonoStyle
        : theme.textTheme.titleMedium?.copyWith(
            fontFamily: DetailLayout.monoFont,
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w500,
          );

    Widget value = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PassportEntryIndicator(entry: entry),
        Expanded(
          child: entry.isData
              ? MixedDataText(
                  entry.value,
                  sansStyle: sansStyle,
                  monoStyle: monoStyle,
                )
              : Text(entry.value, style: sansStyle),
        ),
      ],
    );

    value = AppSkeleton(
      enabled: entry.isDelayed && loading,
      semanticLabel: l10n.animeDetailsLoading,
      child: value,
    );

    var topOffset = 0.0;
    if (alignBaseline) {
      // Shift smaller tiles via Padding rather than Baseline inside
      // IntrinsicHeight because RenderBaseline omits downward shifts from
      // computeMaxIntrinsicHeight and triggers subpixel bottom overflows.
      final textScaler = MediaQuery.textScalerOf(context);
      final textDirection = Directionality.of(context);
      final targetBaseline = math.max(
        _alphabeticBaseline(
          TextSpan(text: '0', style: emphasizedMonoStyle),
          textScaler,
          textDirection,
        ),
        _alphabeticBaseline(
          TextSpan(text: 'А', style: emphasizedSansStyle),
          textScaler,
          textDirection,
        ),
      );
      final sampleText = entry.value.isEmpty ? '0' : entry.value;
      final valueSpan = entry.isData
          ? DetailLayout.mixedDataSpan(
              sampleText,
              sansStyle: sansStyle,
              monoStyle: monoStyle,
            )
          : TextSpan(text: sampleText, style: sansStyle);
      final valueBaseline = _alphabeticBaseline(
        valueSpan,
        textScaler,
        textDirection,
      );
      topOffset = math.max(0.0, targetBaseline - valueBaseline);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Skeleton.keep(
            child: Text(
              entry.label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: DetailLayout.sansFont,
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (topOffset > 0)
            Padding(
              padding: EdgeInsets.only(top: topOffset),
              child: value,
            )
          else
            value,
        ],
      ),
    );
  }
}

class _GenresLine extends StatelessWidget {
  const _GenresLine({
    required this.label,
    required this.value,
    required this.loading,
  });

  final String label;
  final String value;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    Widget text = Text(
      value,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: DetailLayout.sansFont,
      ),
    );
    text = AppSkeleton(
      enabled: loading,
      semanticLabel: l10n.animeDetailsLoading,
      child: text,
    );

    return DecoratedBox(
      decoration: DetailLayout.cardDecoration(scheme),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Skeleton.keep(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: DetailLayout.sansFont,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: text),
          ],
        ),
      ),
    );
  }
}
