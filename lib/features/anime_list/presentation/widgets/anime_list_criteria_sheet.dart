import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_status_label.dart';
import 'package:iris/features/anime_list/domain/entities/anime_genre.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/entities/season_filter.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_search_bloc.dart';
import 'package:iris/features/anime_list/presentation/cubit/anime_genres_cubit.dart';
import 'package:iris/features/anime_list/presentation/cubit/anime_list_preview_cubit.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/show_adaptive_sheet.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/section_label.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/segmented_choice.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// Opens sort and filter controls: a bottom sheet on phones, a dialog on
/// wider windows.
Future<void> showAnimeListCriteriaSheet(
  BuildContext context, {
  String? search,
}) {
  final bloc = context.read<AnimeListBloc>();
  final genres = context.read<AnimeGenresCubit?>()?..load();
  final preview = context.read<AnimeListPreviewCubit?>();
  final searchQuery =
      search ??
      context.read<AnimeSearchBloc?>()?.state.query ??
      bloc.state.query;

  return showAdaptiveSheet<void>(
    context: context,
    builder: (_) => _AnimeListCriteriaSheet(
      bloc: bloc,
      genres: genres,
      preview: preview,
      now: DateTime.now(),
      search: searchQuery,
    ),
  );
}

class _AnimeListCriteriaSheet extends StatefulWidget {
  const _AnimeListCriteriaSheet({
    required this.bloc,
    required this.genres,
    required this.preview,
    required this.now,
    required this.search,
  });

  final AnimeListBloc bloc;
  final String search;

  /// Null leaves genres out.
  final AnimeGenresCubit? genres;
  final AnimeListPreviewCubit? preview;

  /// The day the seasons on offer count from.
  final DateTime now;

  @override
  State<_AnimeListCriteriaSheet> createState() =>
      _AnimeListCriteriaSheetState();
}

class _AnimeListCriteriaSheetState extends State<_AnimeListCriteriaSheet> {
  late AnimeListSortOption _sort;
  late Set<AnimeKindFilter> _kinds;
  late Set<AnimeStatusFilter> _statuses;
  late Set<UserRateStatus> _myList;
  late bool _hideCompleted;
  late Set<AnimeGenre> _genres;
  late Set<SeasonFilter> _seasons;
  late Set<AnimeRatingFilter> _ratings;
  late Set<AnimeDurationFilter> _durations;
  late final List<SeasonFilter> _seasonOptions;
  late final bool _signedIn;

  @override
  void initState() {
    super.initState();
    final state = widget.bloc.state;
    final filters = state.filters;
    _signedIn = state.signedIn;
    _sort = state.sort;
    _kinds = Set.of(filters.kinds);
    _statuses = Set.of(filters.statuses);
    _myList = Set.of(filters.myList);
    _hideCompleted = filters.hideCompleted;
    _genres = Set.of(filters.genres);
    _seasons = Set.of(filters.seasons);
    _ratings = Set.of(filters.ratings);
    _durations = Set.of(filters.durations);
    // A season chosen before the presets moved on stays offered.
    final presets = seasonFilterPresets(widget.now);
    _seasonOptions = [
      ...presets,
      ...filters.seasons.where((season) => !presets.contains(season)),
    ];
    _preview();
  }

  @override
  void dispose() {
    widget.preview?.cancel();
    super.dispose();
  }

  AnimeListFilters get _filters => AnimeListFilters(
    kinds: Set.unmodifiable(_kinds),
    statuses: Set.unmodifiable(_statuses),
    myList: _signedIn ? Set.unmodifiable(_myList) : const {},
    hideCompleted: _signedIn && _hideCompleted,
    genres: Set.unmodifiable(_genres),
    seasons: Set.unmodifiable(_seasons),
    ratings: Set.unmodifiable(_ratings),
    durations: Set.unmodifiable(_durations),
  );

  void _preview() => widget.preview?.update(
    AnimeListQuery(
      page: 1,
      limit: AnimeListPreviewCubit.limit,
      search: widget.search,
      sort: _sort,
      filters: _filters,
    ),
  );

  void _change(VoidCallback change) {
    setState(change);
    _preview();
  }

  void _reset() {
    _change(() {
      _sort = AnimeListSortOption.popularity;
      _kinds = {};
      _statuses = {};
      _myList = {};
      _hideCompleted = false;
      _genres = {};
      _seasons = {};
      _ratings = {};
      _durations = {};
    });
  }

  void _apply() {
    widget.bloc.add(AnimeListCriteriaApplied(sort: _sort, filters: _filters));
    Navigator.of(context).pop();
  }

  void _toggle<T>(Set<T> set, T value, bool selected) {
    _change(() => selected ? set.add(value) : set.remove(value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.animeListFiltersTitle, style: textTheme.titleLarge),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionLabel(l10n.animeListSortSectionTitle),
                      const SizedBox(height: 8),
                      SegmentedChoice<AnimeListSortOption>(
                        key: const Key('catalog_sort_choice'),
                        options: [
                          for (final sort in AnimeListSortOption.values)
                            SegmentedOption(
                              value: sort,
                              label: animeListSortLabel(l10n, sort),
                            ),
                        ],
                        selected: _sort,
                        onSelected: (sort) => _change(() => _sort = sort),
                      ),
                      const SizedBox(height: 20),
                      _CriteriaSection(
                        title: l10n.animeListTypeSectionTitle,
                        options: [
                          for (final kind in AnimeKindFilter.values)
                            _FilterTag(
                              label: animeKindFilterLabel(l10n, kind),
                              selected: _kinds.contains(kind),
                              onChanged: (selected) =>
                                  _toggle(_kinds, kind, selected),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _CriteriaSection(
                        title: l10n.animeListStatusSectionTitle,
                        options: [
                          for (final status in AnimeStatusFilter.values)
                            _FilterTag(
                              label: animeStatusFilterLabel(l10n, status),
                              selected: _statuses.contains(status),
                              onChanged: (selected) =>
                                  _toggle(_statuses, status, selected),
                            ),
                        ],
                      ),
                      if (_signedIn) ...[
                        const SizedBox(height: 20),
                        _CriteriaSection(
                          title: l10n.userRateTitle,
                          options: [
                            for (final status in UserRateStatus.values)
                              _FilterTag(
                                label: userRateStatusLabel(l10n, status),
                                selected: _myList.contains(status),
                                onChanged: (selected) =>
                                    _toggle(_myList, status, selected),
                              ),
                            _FilterTag(
                              label: l10n.animeListHideCompleted,
                              selected: _hideCompleted,
                              onChanged: (selected) =>
                                  _change(() => _hideCompleted = selected),
                            ),
                          ],
                        ),
                      ],
                      if (widget.genres case final genres?)
                        _GenresSection(
                          cubit: genres,
                          selected: _genres,
                          onChanged: (genre, selected) =>
                              _toggle(_genres, genre, selected),
                        ),
                      const SizedBox(height: 20),
                      _CriteriaSection(
                        title: l10n.animeListSeasonSectionTitle,
                        options: [
                          for (final season in _seasonOptions)
                            _FilterTag(
                              label: seasonFilterLabel(l10n, season),
                              selected: _seasons.contains(season),
                              onChanged: (selected) =>
                                  _toggle(_seasons, season, selected),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _CriteriaSection(
                        title: l10n.animeListRatingSectionTitle,
                        options: [
                          for (final rating in AnimeRatingFilter.values)
                            _FilterTag(
                              label: animeRatingFilterLabel(rating),
                              selected: _ratings.contains(rating),
                              onChanged: (selected) =>
                                  _toggle(_ratings, rating, selected),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _CriteriaSection(
                        title: l10n.animeListDurationSectionTitle,
                        options: [
                          for (final duration in AnimeDurationFilter.values)
                            _FilterTag(
                              label: animeDurationFilterLabel(l10n, duration),
                              selected: _durations.contains(duration),
                              onChanged: (selected) =>
                                  _toggle(_durations, duration, selected),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: _reset,
                    child: Text(l10n.animeListResetButton),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: widget.preview != null
                        ? BlocBuilder<AnimeListPreviewCubit, AnimeListPreview>(
                            bloc: widget.preview,
                            builder: (context, state) => FilledButton(
                              onPressed: _apply,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(l10n.animeListShowCount('').trim()),
                                  const SizedBox(width: 8),
                                  Stack(
                                    children: [
                                      const ExcludeSemantics(
                                        child: Opacity(
                                          opacity: 0,
                                          child: Text('50+'),
                                        ),
                                      ),
                                      AppSkeleton(
                                        enabled: state.loading,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                        semanticLabel: l10n.animeListLoading,
                                        child: Text(
                                          state.loading
                                              ? '00'
                                              : state.count == null
                                              ? ''
                                              : '${state.count}${state.hasMore ? '+' : ''}',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                        : FilledButton(
                            onPressed: _apply,
                            child: Text(l10n.animeListShowResults),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenresSection extends StatefulWidget {
  const _GenresSection({
    required this.cubit,
    required this.selected,
    required this.onChanged,
  });
  final AnimeGenresCubit cubit;
  final Set<AnimeGenre> selected;
  final void Function(AnimeGenre genre, bool selected) onChanged;

  @override
  State<_GenresSection> createState() => _GenresSectionState();
}

class _GenresSectionState extends State<_GenresSection> {
  final _expanded = <AnimeGenreKind>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<AnimeGenresCubit, AnimeGenresState>(
      bloc: widget.cubit,
      builder: (context, state) {
        if (state is AnimeGenresUnavailable) return const SizedBox.shrink();
        if (state is! AnimeGenresLoaded) {
          return const Padding(
            padding: EdgeInsets.only(top: 20),
            child: SizedBox(width: 80, child: BlockSpinner()),
          );
        }
        final sections = <Widget>[];
        for (final kind in AnimeGenreKind.values) {
          final all = state.genres
              .where((genre) => genre.kind == kind)
              .toList();
          if (all.isEmpty) continue;
          final expanded = _expanded.contains(kind);
          final visible = [
            for (final (index, genre) in all.indexed)
              if (expanded ||
                  kind == AnimeGenreKind.demographic ||
                  index < 10 ||
                  widget.selected.contains(genre))
                genre,
          ];
          sections.addAll([
            const SizedBox(height: 20),
            _CriteriaSection(
              title: switch (kind) {
                AnimeGenreKind.genre => l10n.animeListGenresSectionTitle,
                AnimeGenreKind.demographic =>
                  l10n.animeListDemographicsSectionTitle,
                AnimeGenreKind.theme => l10n.animeListThemesSectionTitle,
              },
              options: [
                for (final genre in visible)
                  _FilterTag(
                    label: animeGenreLabel(l10n, genre),
                    selected: widget.selected.contains(genre),
                    onChanged: (selected) => widget.onChanged(genre, selected),
                  ),
                if (visible.length < all.length || expanded)
                  TextButton.icon(
                    onPressed: () => setState(
                      () => expanded
                          ? _expanded.remove(kind)
                          : _expanded.add(kind),
                    ),
                    icon: RotatedBox(
                      quarterTurns: expanded ? 2 : 0,
                      child: const PixelIcon(PixelGlyph.expand, size: 12),
                    ),
                    label: Text(
                      expanded
                          ? l10n.animeListCollapse
                          : l10n.animeListShowMore(all.length - visible.length),
                    ),
                  ),
              ],
            ),
          ]);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sections,
        );
      },
    );
  }
}

class _FilterTag extends StatelessWidget {
  const _FilterTag({
    required this.label,
    required this.selected,
    required this.onChanged,
  });
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        onPressed: () => onChanged(!selected),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          backgroundColor: selected ? scheme.onSurface : scheme.surface,
          foregroundColor: selected ? scheme.surface : scheme.onSurface,
          overlayColor: selected ? scheme.surface : scheme.onSurface,
          side: BorderSide(color: selected ? scheme.onSurface : scheme.outline),
        ),
        child: Text(label),
      ),
    );
  }
}

class _CriteriaSection extends StatelessWidget {
  const _CriteriaSection({required this.title, required this.options});

  final String title;
  final List<Widget> options;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(title),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 8, children: options),
      ],
    );
  }
}

/// How the catalog is ordered, as the sort control names it.
String animeListSortLabel(AppLocalizations l10n, AnimeListSortOption sort) =>
    switch (sort) {
      AnimeListSortOption.popularity => l10n.animeListSortPopularity,
      AnimeListSortOption.score => l10n.animeListSortScore,
      AnimeListSortOption.airedOn => l10n.animeListSortAiredOn,
    };

String animeKindFilterLabel(AppLocalizations l10n, AnimeKindFilter kind) =>
    switch (kind) {
      AnimeKindFilter.tv => l10n.animeKindTv,
      AnimeKindFilter.movie => l10n.animeKindMovie,
      AnimeKindFilter.ova => l10n.animeKindOva,
      AnimeKindFilter.ona => l10n.animeKindOna,
    };

String animeStatusFilterLabel(
  AppLocalizations l10n,
  AnimeStatusFilter status,
) => switch (status) {
  AnimeStatusFilter.released => l10n.animeStatusReleased,
  AnimeStatusFilter.ongoing => l10n.animeStatusOngoing,
  AnimeStatusFilter.announced => l10n.animeStatusAnnounced,
};

String animeRatingFilterLabel(AnimeRatingFilter rating) => switch (rating) {
  AnimeRatingFilter.g => 'G',
  AnimeRatingFilter.pg => 'PG',
  AnimeRatingFilter.pg13 => 'PG-13',
  AnimeRatingFilter.r => 'R-17',
  AnimeRatingFilter.rPlus => 'R+',
};

String animeDurationFilterLabel(
  AppLocalizations l10n,
  AnimeDurationFilter duration,
) => switch (duration) {
  AnimeDurationFilter.short => l10n.animeDurationShort,
  AnimeDurationFilter.standard => l10n.animeDurationStandard,
  AnimeDurationFilter.long => l10n.animeDurationLong,
};

String seasonFilterLabel(AppLocalizations l10n, SeasonFilter season) {
  final year = '${season.year}';
  return switch (season.kind) {
    SeasonFilterKind.season => switch (season.season!) {
      AnimeSeason.winter => l10n.animeSeasonWinter(year),
      AnimeSeason.spring => l10n.animeSeasonSpring(year),
      AnimeSeason.summer => l10n.animeSeasonSummer(year),
      AnimeSeason.fall => l10n.animeSeasonFall(year),
    },
    SeasonFilterKind.year => year,
    SeasonFilterKind.decade => l10n.animeListDecade(year),
    SeasonFilterKind.before2000 => l10n.animeListBefore2000,
  };
}

/// The genre's name in the app's language, Shikimori's own otherwise.
String animeGenreLabel(AppLocalizations l10n, AnimeGenre genre) =>
    l10n.localeName.startsWith('ru') && genre.russian.isNotEmpty
    ? genre.russian
    : genre.name;
