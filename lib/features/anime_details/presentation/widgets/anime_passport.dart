import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:iris/features/anime_details/domain/entities/anime_genre_name.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

/// A single metadata cell rendered inside a passport or highlight strip.
class PassportEntry {
  const PassportEntry({
    required this.label,
    required this.value,
    this.isLive = false,
    this.isAnnouncement = false,
    this.isDelayed = false,
    this.emphasize = false,
    this.isData = false,
  });

  final String label;
  final String value;
  final bool isLive;
  final bool isAnnouncement;
  final bool isDelayed;
  final bool emphasize;
  final bool isData;
}

/// Builds the full list of metadata entries in display order, marking those
/// that arrive only once full details finish loading as [PassportEntry.isDelayed].
List<PassportEntry> buildAnimePassportEntries(
  AppLocalizations l10n,
  AnimeDetailsPreview head, {
  required bool loading,
  bool includeScore = true,
  bool includeEpisodes = true,
  bool includeNextEpisode = true,
  bool includeGenres = true,
}) {
  final episodes = formatAnimeEpisodesValue(l10n, head);
  final nextEpisode = nextEpisodePassportEntry(l10n, head, loading: loading);

  final studioValue = loading
      ? 'Studio name'
      : (head.studios.isNotEmpty ? head.studios.join(', ') : null);
  final genresValue = animeGenresLineValue(l10n, head, loading: loading);
  final ratingValue = loading ? 'PG-13' : formatAgeRating(head.rating);

  return [
    if (includeScore && head.anime.score > 0)
      PassportEntry(
        label: l10n.animeDetailsFactScore,
        value: formatAnimeScoreValue(l10n, head.anime.score),
        emphasize: true,
        isData: true,
      ),
    if (includeEpisodes && episodes != null)
      PassportEntry(
        label: l10n.animeDetailsFactEpisodes,
        value: episodes,
        emphasize: true,
        isData: true,
      ),
    if (includeNextEpisode && nextEpisode != null) nextEpisode,
    PassportEntry(
      label: l10n.animeDetailsFactStatus,
      value: formatAnimeStatus(l10n, head.anime.status),
      isLive: head.anime.status == 'ongoing',
      emphasize: true,
    ),
    PassportEntry(
      label: l10n.animeDetailsFactKind,
      value: formatAnimeKind(l10n, head.anime.kind),
    ),
    if (head.anime.airedOn.isNotEmpty)
      PassportEntry(
        label: l10n.animeDetailsFactAired,
        value: formatAiredOn(l10n, head.anime.airedOn),
        isData: true,
      ),
    if (ratingValue != null)
      PassportEntry(
        label: l10n.animeDetailsFactRating,
        value: ratingValue,
        isDelayed: loading,
      ),
    if (studioValue != null)
      PassportEntry(
        label: l10n.animeDetailsFactStudio,
        value: studioValue,
        isDelayed: loading,
      ),
    if (includeGenres && genresValue != null)
      PassportEntry(
        label: l10n.animeDetailsFactGenres,
        value: genresValue,
        isDelayed: loading,
      ),
  ];
}

/// Formats the total or aired/total episode count for [head].
String? formatAnimeEpisodesValue(
  AppLocalizations l10n,
  AnimeDetailsPreview head,
) {
  final total = head.anime.episodes;
  final aired = head.anime.episodesAired;
  if (total > 0 && (head.anime.status == 'released' || aired >= total)) {
    return total.toString();
  }
  if (total > 0) {
    return l10n.animeDetailsEpisodesAired(aired.toString(), total.toString());
  }
  if (aired > 0) return aired.toString();
  return null;
}

/// Builds the upcoming-episode entry for airing titles, or a skeleton placeholder
/// only when [head.anime.status] indicates an ongoing series.
PassportEntry? nextEpisodePassportEntry(
  AppLocalizations l10n,
  AnimeDetailsPreview head, {
  required bool loading,
}) {
  if (loading) {
    if (head.anime.status != 'ongoing') return null;
    return PassportEntry(
      label: l10n.animeDetailsFactNextEpisode,
      value: 'Episode 7 in 3 days',
      isAnnouncement: true,
      isDelayed: true,
      isData: true,
    );
  }
  final at = head.anime.nextEpisodeAt;
  if (head.anime.status != 'ongoing' || at == null) return null;
  final when = formatNextEpisodeTime(l10n, at, DateTime.now());
  if (when == null) return null;
  return PassportEntry(
    label: l10n.animeDetailsFactNextEpisode,
    value: l10n.animeNextEpisode(head.anime.episodesAired + 1, when),
    isAnnouncement: true,
    isData: true,
  );
}

/// Comma-separated localized genre list, or placeholder text while loading.
String? animeGenresLineValue(
  AppLocalizations l10n,
  AnimeDetailsPreview head, {
  required bool loading,
}) {
  if (loading) return 'Action, Drama, Fantasy';
  if (head.genres.isEmpty) return null;
  return [for (final genre in head.genres) _genreName(l10n, genre)].join(', ');
}

String _genreName(AppLocalizations l10n, AnimeGenreName genre) =>
    l10n.localeName == 'ru' && genre.russian.isNotEmpty
    ? genre.russian
    : genre.name;

/// Leading indicator for live status (solid square) or upcoming episode (pixel
/// play triangle), kept distinct so announcements do not look identical to
/// "watching/airing".
class PassportEntryIndicator extends StatelessWidget {
  const PassportEntryIndicator({required this.entry, super.key});

  final PassportEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (entry.isLive) {
      return Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.only(right: 8),
        color: scheme.tertiary,
      );
    }
    if (entry.isAnnouncement) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: PixelIcon(PixelGlyph.play, size: 9, color: scheme.tertiary),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Framed architectural spec matrix used on compact/medium screens and in the
/// desktop left rail.
///
/// Short pairs share a two-column hairline grid while [isFullWidth] entries
/// (next episode right beneath score/episodes, studios, genres) span full width.
class AnimePassportCard extends StatelessWidget {
  const AnimePassportCard({
    required this.entries,
    required this.loading,
    this.twoColumns = true,
    this.markMoreFactsKey = true,
    super.key,
  });

  final List<PassportEntry> entries;
  final bool loading;
  final bool twoColumns;
  final bool markMoreFactsKey;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final ruleColor = DetailLayout.ruleColor(scheme);
    final useGrid = twoColumns && !DetailLayout.isLargeText(context);

    bool isFullWidth(PassportEntry entry) =>
        !useGrid ||
        entry.label == l10n.animeDetailsFactNextEpisode ||
        entry.label == l10n.animeDetailsFactStudio ||
        entry.label == l10n.animeDetailsFactGenres;

    // Pair consecutive short entries into two-column rows while flushing on
    // full-width entries so release telemetry (next episode) stays near the top.
    final rows = <Widget>[];
    PassportEntry? pendingLeft;

    void flushPending() {
      final left = pendingLeft;
      if (left == null) return;
      rows.add(_PassportCell(entry: left, loading: loading));
      pendingLeft = null;
    }

    for (final entry in entries) {
      if (isFullWidth(entry)) {
        flushPending();
        rows.add(_PassportCell(entry: entry, loading: loading));
      } else if (pendingLeft == null) {
        pendingLeft = entry;
      } else {
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _PassportCell(entry: pendingLeft!, loading: loading),
                ),
                VerticalDivider(width: 1, thickness: 1, color: ruleColor),
                Expanded(
                  child: _PassportCell(entry: entry, loading: loading),
                ),
              ],
            ),
          ),
        );
        pendingLeft = null;
      }
    }
    flushPending();

    return DecoratedBox(
      key: markMoreFactsKey ? const Key('anime_details_more_facts') : null,
      decoration: DetailLayout.cardDecoration(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) Divider(height: 1, thickness: 1, color: ruleColor),
            row,
          ],
        ],
      ),
    );
  }
}

class _PassportCell extends StatelessWidget {
  const _PassportCell({required this.entry, required this.loading});

  final PassportEntry entry;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final sansStyle = entry.emphasize
        ? theme.textTheme.titleMedium?.copyWith(
            fontFamily: DetailLayout.sansFont,
            fontWeight: FontWeight.w500,
          )
        : theme.textTheme.bodyMedium?.copyWith(
            fontFamily: DetailLayout.sansFont,
          );
    final monoStyle = entry.emphasize
        ? theme.textTheme.titleMedium?.copyWith(
            fontFamily: DetailLayout.monoFont,
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w600,
          )
        : theme.textTheme.bodyMedium?.copyWith(
            fontFamily: DetailLayout.monoFont,
            fontFeatures: const [FontFeature.tabularFigures()],
          );

    Widget valueWidget = Row(
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

    valueWidget = AppSkeleton(
      enabled: entry.isDelayed && loading,
      semanticLabel: l10n.animeDetailsLoading,
      child: valueWidget,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          const SizedBox(height: 3),
          valueWidget,
        ],
      ),
    );
  }
}
