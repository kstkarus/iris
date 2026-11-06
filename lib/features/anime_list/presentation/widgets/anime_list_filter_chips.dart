import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/user_rate/presentation/user_rate_status_label.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_list_criteria_sheet.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/dither_list.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

class AnimeListFilterChips extends StatelessWidget {
  const AnimeListFilterChips({
    required this.filters,
    this.padding = EdgeInsets.zero,
    super.key,
  });
  final AnimeListFilters filters;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = <({Object key, String label, AnimeListFilters remaining})>[
      for (final value in AnimeKindFilter.values)
        if (filters.kinds.contains(value))
          (
            key: value,
            label: animeKindFilterLabel(l10n, value),
            remaining: filters.copyWith(
              kinds: {...filters.kinds}..remove(value),
            ),
          ),
      for (final value in AnimeStatusFilter.values)
        if (filters.statuses.contains(value))
          (
            key: value,
            label: animeStatusFilterLabel(l10n, value),
            remaining: filters.copyWith(
              statuses: {...filters.statuses}..remove(value),
            ),
          ),
      for (final value in filters.myList)
        (
          key: value,
          label: userRateStatusLabel(l10n, value),
          remaining: filters.copyWith(
            myList: {...filters.myList}..remove(value),
          ),
        ),
      if (filters.hideCompleted)
        (
          key: 'hideCompleted',
          label: l10n.animeListHideCompleted,
          remaining: filters.copyWith(hideCompleted: false),
        ),
      for (final value in filters.genres)
        (
          key: value,
          label: animeGenreLabel(l10n, value),
          remaining: filters.copyWith(
            genres: {...filters.genres}..remove(value),
          ),
        ),
      for (final value in filters.seasons)
        (
          key: value,
          label: seasonFilterLabel(l10n, value),
          remaining: filters.copyWith(
            seasons: {...filters.seasons}..remove(value),
          ),
        ),
      for (final value in AnimeRatingFilter.values)
        if (filters.ratings.contains(value))
          (
            key: value,
            label: animeRatingFilterLabel(value),
            remaining: filters.copyWith(
              ratings: {...filters.ratings}..remove(value),
            ),
          ),
      for (final value in AnimeDurationFilter.values)
        if (filters.durations.contains(value))
          (
            key: value,
            label: animeDurationFilterLabel(l10n, value),
            remaining: filters.copyWith(
              durations: {...filters.durations}..remove(value),
            ),
          ),
    ];
    void apply(AnimeListFilters value) => context.read<AnimeListBloc>().add(
      AnimeListCriteriaApplied(filters: value),
    );
    return DitherSwitcher(
      collapse: true,
      reverseDuration: DitherList.horizontalRemovalDuration,
      child: !filters.hasAny
          ? const SizedBox.shrink(key: ValueKey(false))
          : SingleChildScrollView(
              key: const Key('catalog_active_filters'),
              scrollDirection: Axis.horizontal,
              padding: padding,
              child: DitherList.horizontal(
                items: entries,
                keyOf: (entry) => entry.key,
                itemBuilder: (context, entry) => Tooltip(
                  key: ValueKey(('catalog_filter', entry.key)),
                  message: l10n.animeListRemoveFilter(entry.label),
                  child: OutlinedButton(
                    onPressed: () => apply(entry.remaining),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text(entry.label)),
                        const SizedBox(width: 10),
                        PixelIcon(
                          PixelGlyph.close,
                          size: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                footer: TextButton(
                  onPressed: () => apply(const AnimeListFilters()),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 44),
                    alignment: AlignmentDirectional.centerStart,
                  ),
                  child: Text(l10n.animeListResetButton),
                ),
              ),
            ),
    );
  }
}
