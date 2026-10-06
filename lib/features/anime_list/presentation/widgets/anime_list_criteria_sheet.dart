import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/show_adaptive_sheet.dart';

/// Opens sort and filter controls: a bottom sheet on phones, a dialog on
/// wider windows.
Future<void> showAnimeListCriteriaSheet(BuildContext context) {
  final bloc = context.read<AnimeListBloc>();

  return showAdaptiveSheet<void>(
    context: context,
    builder: (_) => _AnimeListCriteriaSheet(bloc: bloc),
  );
}

class _AnimeListCriteriaSheet extends StatefulWidget {
  const _AnimeListCriteriaSheet({required this.bloc});

  final AnimeListBloc bloc;

  @override
  State<_AnimeListCriteriaSheet> createState() =>
      _AnimeListCriteriaSheetState();
}

class _AnimeListCriteriaSheetState extends State<_AnimeListCriteriaSheet> {
  late AnimeListSortOption _sort;
  late Set<AnimeKindFilter> _kinds;
  late Set<AnimeStatusFilter> _statuses;

  @override
  void initState() {
    super.initState();
    final state = widget.bloc.state;
    _sort = state.sort;
    _kinds = Set<AnimeKindFilter>.from(state.filters.kinds);
    _statuses = Set<AnimeStatusFilter>.from(state.filters.statuses);
  }

  void _reset() {
    setState(() {
      _sort = AnimeListSortOption.popularity;
      _kinds = <AnimeKindFilter>{};
      _statuses = <AnimeStatusFilter>{};
    });
  }

  void _apply() {
    widget.bloc.add(
      AnimeListCriteriaApplied(
        sort: _sort,
        filters: AnimeListFilters(kinds: _kinds, statuses: _statuses),
      ),
    );
    Navigator.of(context).pop();
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
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CriteriaSection(
                      title: l10n.animeListSortSectionTitle,
                      chips: [
                        for (final sort in AnimeListSortOption.values)
                          ChoiceChip(
                            label: Text(_formatSortLabel(l10n, sort)),
                            selected: _sort == sort,
                            onSelected: (_) => setState(() => _sort = sort),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _CriteriaSection(
                      title: l10n.animeListTypeSectionTitle,
                      chips: [
                        for (final kind in AnimeKindFilter.values)
                          FilterChip(
                            label: Text(_formatKindLabel(l10n, kind)),
                            selected: _kinds.contains(kind),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _kinds.add(kind);
                              } else {
                                _kinds.remove(kind);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _CriteriaSection(
                      title: l10n.animeListStatusSectionTitle,
                      chips: [
                        for (final status in AnimeStatusFilter.values)
                          FilterChip(
                            label: Text(_formatStatusLabel(l10n, status)),
                            selected: _statuses.contains(status),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _statuses.add(status);
                              } else {
                                _statuses.remove(status);
                              }
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton(
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

class _CriteriaSection extends StatelessWidget {
  const _CriteriaSection({required this.title, required this.chips});

  final String title;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }
}

String _formatSortLabel(AppLocalizations l10n, AnimeListSortOption sort) {
  switch (sort) {
    case AnimeListSortOption.popularity:
      return l10n.animeListSortPopularity;
    case AnimeListSortOption.score:
      return l10n.animeListSortScore;
    case AnimeListSortOption.airedOn:
      return l10n.animeListSortAiredOn;
  }
}

String _formatKindLabel(AppLocalizations l10n, AnimeKindFilter kind) {
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

String _formatStatusLabel(AppLocalizations l10n, AnimeStatusFilter status) {
  switch (status) {
    case AnimeStatusFilter.released:
      return l10n.animeStatusReleased;
    case AnimeStatusFilter.ongoing:
      return l10n.animeStatusOngoing;
    case AnimeStatusFilter.announced:
      return l10n.animeStatusAnnounced;
  }
}
