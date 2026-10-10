import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_status_label.dart';
import 'package:iris/features/anime_list/domain/entities/anime_genre.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/entities/season_filter.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/cubit/anime_genres_cubit.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';
import 'package:iris/shared/widgets/adaptive/show_adaptive_sheet.dart';
import 'package:iris/shared/widgets/option_toggle.dart';
import 'package:iris/shared/widgets/section_label.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// Opens sort and filter controls: a bottom sheet on phones, a dialog on
/// wider windows.
Future<void> showAnimeListCriteriaSheet(BuildContext context) {
  final bloc = context.read<AnimeListBloc>();
  final genres = context.read<AnimeGenresCubit?>()?..load();

  return showAdaptiveSheet<void>(
    context: context,
    builder: (_) => _AnimeListCriteriaSheet(
      bloc: bloc,
      genres: genres,
      now: DateTime.now(),
    ),
  );
}

class _AnimeListCriteriaSheet extends StatefulWidget {
  const _AnimeListCriteriaSheet({
    required this.bloc,
    required this.genres,
    required this.now,
  });

  final AnimeListBloc bloc;

  /// Null leaves genres out.
  final AnimeGenresCubit? genres;

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
  }

  void _reset() {
    setState(() {
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
    widget.bloc.add(
      AnimeListCriteriaApplied(
        sort: _sort,
        filters: AnimeListFilters(
          kinds: _kinds,
          statuses: _statuses,
          myList: _signedIn ? _myList : const {},
          hideCompleted: _signedIn && _hideCompleted,
          genres: _genres,
          seasons: _seasons,
          ratings: _ratings,
          durations: _durations,
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  void _toggle<T>(Set<T> set, T value, bool selected) {
    setState(() => selected ? set.add(value) : set.remove(value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.animeListFilterSortTitle, style: textTheme.titleLarge),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CriteriaSection(
                      title: l10n.animeListSortSectionTitle,
                      options: [
                        for (final sort in AnimeListSortOption.values)
                          OptionToggle(
                            label: animeListSortLabel(l10n, sort),
                            selected: _sort == sort,
                            exclusive: true,
                            onChanged: (_) => setState(() => _sort = sort),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _CriteriaSection(
                      title: l10n.animeListTypeSectionTitle,
                      options: [
                        for (final kind in AnimeKindFilter.values)
                          OptionToggle(
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
                          OptionToggle(
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
                            OptionToggle(
                              label: userRateStatusLabel(l10n, status),
                              selected: _myList.contains(status),
                              onChanged: (selected) =>
                                  _toggle(_myList, status, selected),
                            ),
                          OptionToggle(
                            label: l10n.animeListHideCompleted,
                            selected: _hideCompleted,
                            onChanged: (selected) =>
                                setState(() => _hideCompleted = selected),
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
                          OptionToggle(
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
                          OptionToggle(
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
                          OptionToggle(
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
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  onPressed: _reset,
                  child: Text(l10n.animeListResetButton),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _apply,
                  child: Text(l10n.animeListApplyButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Genres and audiences at once, the many themes a tap away; while they
/// load, a spinner holds their place, and if they do not, the section is
/// left out.
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
  // A theme already chosen is never folded away.
  late bool _themesShown = widget.selected.any(
    (genre) => genre.kind == AnimeGenreKind.theme,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<AnimeGenresCubit, AnimeGenresState>(
      bloc: widget.cubit,
      builder: (context, state) {
        final List<Widget> options;
        switch (state) {
          case AnimeGenresUnavailable():
            return const SizedBox.shrink();
          case AnimeGenresIdle() || AnimeGenresLoading():
            options = const [
              Padding(
                padding: EdgeInsets.fromLTRB(8, 12, 0, 12),
                child: SizedBox(width: 80, child: BlockSpinner()),
              ),
            ];
          case AnimeGenresLoaded(:final genres):
            final themes = [
              for (final genre in genres)
                if (genre.kind == AnimeGenreKind.theme) genre,
            ];
            options = [
              for (final genre in genres)
                if (genre.kind != AnimeGenreKind.theme || _themesShown)
                  OptionToggle(
                    label: animeGenreLabel(l10n, genre),
                    selected: widget.selected.contains(genre),
                    onChanged: (selected) {
                      setState(() => widget.onChanged(genre, selected));
                    },
                  ),
              if (themes.isNotEmpty && !_themesShown)
                TextButton(
                  onPressed: () => setState(() => _themesShown = true),
                  child: Text(l10n.animeListShowThemes(themes.length)),
                ),
            ];
        }
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _CriteriaSection(
            title: l10n.animeListGenresSectionTitle,
            options: options,
          ),
        );
      },
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
        // The boxes line up with the label above them.
        Transform.translate(
          offset: const Offset(-8, 0),
          child: Wrap(spacing: 8, children: options),
        ),
      ],
    );
  }
}

/// How the catalog is ordered, as the sort control and the catalog's
/// section label name it.
String animeListSortLabel(AppLocalizations l10n, AnimeListSortOption sort) {
  switch (sort) {
    case AnimeListSortOption.popularity:
      return l10n.animeListSortPopularity;
    case AnimeListSortOption.score:
      return l10n.animeListSortScore;
    case AnimeListSortOption.airedOn:
      return l10n.animeListSortAiredOn;
  }
}

String animeKindFilterLabel(AppLocalizations l10n, AnimeKindFilter kind) {
  switch (kind) {
    case AnimeKindFilter.tv:
      return l10n.animeKindTv;
    case AnimeKindFilter.movie:
      return l10n.animeKindMovie;
    case AnimeKindFilter.ova:
      return l10n.animeKindOva;
    case AnimeKindFilter.ona:
      return l10n.animeKindOna;
  }
}

String animeStatusFilterLabel(AppLocalizations l10n, AnimeStatusFilter status) {
  switch (status) {
    case AnimeStatusFilter.released:
      return l10n.animeStatusReleased;
    case AnimeStatusFilter.ongoing:
      return l10n.animeStatusOngoing;
    case AnimeStatusFilter.announced:
      return l10n.animeStatusAnnounced;
  }
}

String animeRatingFilterLabel(AnimeRatingFilter rating) =>
    formatAgeRating(rating.apiValue) ?? rating.apiValue;

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
