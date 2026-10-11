import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_status_label.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_state.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_search_bloc.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_grid.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_list_criteria_sheet.dart';
import 'package:iris/features/anime_list/presentation/widgets/continue_watching_row.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/bayer_mask.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/caption_text.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/dither_transition.dart';
import 'package:iris/shared/widgets/display_title.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/search_field.dart';
import 'package:iris/shared/widgets/search_toolbar.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// The catalog under a search field.
///
/// Searching is a mode entered on purpose, by focusing the field, so the
/// page changes once rather than with every keystroke: the catalog scrolls
/// its header away and the grid sits under the field. Typing develops the
/// results over the catalog; clearing the field brings the catalog back
/// without leaving the mode. Cancel, Escape, Back, or leaving an empty
/// field ends it, and the catalog returns to where it was. Results live in
/// their own [AnimeSearchBloc], so the catalog never reloads for a search.
class AnimeListView extends StatefulWidget {
  const AnimeListView({super.key});

  @override
  State<AnimeListView> createState() => _AnimeListViewState();
}

class _AnimeListViewState extends State<AnimeListView>
    with SingleTickerProviderStateMixin {
  static const _minCardWidth = 150.0;
  static const _maxColumns = 8;
  static const _searchDebounceDuration = Duration(milliseconds: 400);
  static const _scrollDuration = Duration(milliseconds: 320);

  final _catalogScroll = ScrollController();
  final _resultsScroll = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _headerKey = GlobalKey();

  /// 0 shows the catalog, 1 the search results.
  late final AnimationController _results = AnimationController(
    vsync: this,
    duration: DitherTransition.duration,
  );
  Timer? _searchDebounceTimer;
  bool _searching = false;

  /// Where the catalog was before the search moved it, and where it left
  /// it; the catalog goes back only if it was not scrolled further since.
  ({double before, double after})? _catalogShift;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _catalogScroll.dispose();
    _resultsScroll.dispose();
    _searchController.dispose();
    _results.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_searchFocus.hasFocus) {
      _enterSearch();
      return;
    }
    // Focus that moves to a sheet or a page on top keeps the search.
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    if (onTop && _searchController.text.trim().isEmpty) _exitSearch();
  }

  void _enterSearch() {
    if (_searching) return;
    setState(() => _searching = true);

    final header = _headerKey.currentContext?.findRenderObject();
    if (!_catalogScroll.hasClients || header is! RenderBox || !header.hasSize) {
      return;
    }
    final position = _catalogScroll.position;
    final target = math.min(
      header.size.height + AnimeGrid.headerGap,
      position.maxScrollExtent,
    );
    if (position.pixels >= target) return;
    _catalogShift = (before: position.pixels, after: target);
    _scrollCatalog(target);
  }

  void _exitSearch() {
    if (!_searching) return;
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    context.read<AnimeSearchBloc>().add(const AnimeListSearchCleared());
    setState(() => _searching = false);
    _searchFocus.unfocus();

    final shift = _catalogShift;
    _catalogShift = null;
    if (shift != null &&
        _catalogScroll.hasClients &&
        _catalogScroll.position.pixels <= shift.after + 1) {
      _scrollCatalog(shift.before);
    }
  }

  void _scrollCatalog(double offset) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _catalogScroll.jumpTo(offset);
    } else {
      _catalogScroll.animateTo(
        offset,
        duration: _scrollDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    final query = value.trim();
    // An emptied field brings the catalog back at once.
    if (query.isEmpty) {
      context.read<AnimeSearchBloc>().add(const AnimeListSearchCleared());
      return;
    }
    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      if (!mounted) return;
      context.read<AnimeSearchBloc>().add(AnimeListSearchChanged(query));
    });
  }

  void _onSearchQueryChanged(BuildContext context, AnimeListState state) {
    if (_resultsScroll.hasClients) _resultsScroll.jumpTo(0);
    final show = state.query.isNotEmpty;
    if (MediaQuery.disableAnimationsOf(context)) {
      _results.value = show ? 1 : 0;
    } else if (show) {
      _results.forward();
    } else {
      _results.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSearch();
      },
      child: MultiBlocListener(
        listeners: [
          // Sort and filters narrow the results the same way.
          BlocListener<AnimeListBloc, AnimeListState>(
            listenWhen: (previous, current) =>
                previous.sort != current.sort ||
                previous.filters != current.filters,
            listener: (context, state) => context.read<AnimeSearchBloc>().add(
              AnimeListCriteriaApplied(
                sort: state.sort,
                filters: state.filters,
              ),
            ),
          ),
          BlocListener<AnimeSearchBloc, AnimeListState>(
            listenWhen: (previous, current) => previous.query != current.query,
            listener: _onSearchQueryChanged,
          ),
        ],
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = adaptiveColumnCount(
              availableWidth: constraints.maxWidth,
              minItemWidth: _minCardWidth,
              spacing: AnimeGrid.columnSpacing,
              maxColumns: _maxColumns,
            );
            final isWide =
                constraints.maxWidth >= WindowSizeClass.mediumMinWidth;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape):
                        _exitSearch,
                  },
                  child: _SearchControls(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: _onSearchChanged,
                    isWide: isWide,
                    // Wide windows leave with Escape or a click elsewhere.
                    onCancel: _searching && !isWide ? _exitSearch : null,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _Layers(
                    results: _results,
                    catalog: _CatalogPane(
                      columns: columns,
                      controller: _catalogScroll,
                      headerKey: _headerKey,
                    ),
                    search: _ResultsPane(
                      columns: columns,
                      controller: _resultsScroll,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchControls extends StatelessWidget {
  const _SearchControls({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.isWide,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool isWide;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final narrowed = context.select<AnimeListBloc, bool>(
      (bloc) =>
          bloc.state.filters.hasAny ||
          bloc.state.sort != AnimeListSortOption.popularity,
    );
    return SearchToolbar(
      searchField: SearchField(
        controller: controller,
        focusNode: focusNode,
        hintText: l10n.animeListSearchHint,
        onChanged: onChanged,
      ),
      actionIcon: PixelGlyph.tune,
      actionLabel: l10n.animeListFilterSortButton,
      actionActive: narrowed,
      onAction: () => showAnimeListCriteriaSheet(context),
      isWide: isWide,
      onCancel: onCancel,
    );
  }
}

/// The catalog with the search results over it. The results develop over
/// the catalog cell by cell and go the same way; the catalog stays mounted
/// underneath, scroll position and all.
class _Layers extends StatelessWidget {
  const _Layers({
    required this.results,
    required this.catalog,
    required this.search,
  });

  final Animation<double> results;
  final Widget catalog;
  final Widget search;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: results,
      builder: (context, _) {
        final open = (results.value * BayerMask.steps).round();
        final covered = open >= BayerMask.steps;
        return Stack(
          fit: StackFit.expand,
          children: [
            Offstage(
              offstage: covered,
              child: TickerMode(
                enabled: !covered,
                child: BayerMasked(open: open, inverse: true, child: catalog),
              ),
            ),
            if (open > 0) BayerMasked(open: open, child: search),
          ],
        );
      },
    );
  }
}

class _CatalogPane extends StatelessWidget {
  const _CatalogPane({
    required this.columns,
    required this.controller,
    required this.headerKey,
  });

  final int columns;
  final ScrollController controller;
  final Key headerKey;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnimeListBloc, AnimeListState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context);
        final bloc = context.read<AnimeListBloc>();
        // Local history: it stays when the catalog cannot load.
        final continueItems = continueWatchingItems(
          context.watchWatchProgress(),
        );
        if (!state.isInitialLoading) {
          if (state.errorType == AnimeListErrorType.initial &&
              !state.hasLoadedOnce) {
            if (continueItems.isEmpty) return _FailureState(bloc: bloc);
            return CustomScrollView(
              controller: controller,
              slivers: [
                SliverToBoxAdapter(
                  child: KeyedSubtree(
                    key: headerKey,
                    child: ContinueWatchingRow(items: continueItems),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _FailureState(bloc: bloc),
                ),
              ],
            );
          }
          if (state.hasLoadedOnce && state.items.isEmpty) {
            return MessageView(
              message: state.filters.hasAny
                  ? l10n.animeListCriteriaEmpty
                  : l10n.animeListEmpty,
            );
          }
        }

        return AnimeGrid(
          bloc: bloc,
          state: state,
          columns: columns,
          controller: controller,
          header: KeyedSubtree(
            key: headerKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (continueItems.isNotEmpty) ...[
                  ContinueWatchingRow(items: continueItems),
                  const SizedBox(height: 56),
                ],
                _CatalogHeading(state: state),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Search results speak for themselves: no header over them.
class _ResultsPane extends StatelessWidget {
  const _ResultsPane({required this.columns, required this.controller});

  final int columns;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnimeSearchBloc, AnimeListState>(
      // The last results stay while they make way for the catalog.
      buildWhen: (previous, current) => current.query.isNotEmpty,
      builder: (context, state) {
        final bloc = context.read<AnimeSearchBloc>();
        if (!state.isInitialLoading) {
          if (state.errorType == AnimeListErrorType.initial &&
              !state.hasLoadedOnce) {
            return _FailureState(bloc: bloc);
          }
          if (state.hasLoadedOnce && state.items.isEmpty) {
            return MessageView(
              message: AppLocalizations.of(context).animeListSearchEmpty,
            );
          }
        }
        return AnimeGrid(
          bloc: bloc,
          state: state,
          columns: columns,
          controller: controller,
        );
      },
    );
  }
}

/// The catalog's one big word: what the list below is, by its order.
/// Active filters follow it in small type. When the
/// order or filters change, the words dissolve into the new ones while the
/// grid below turns to noise.
class _CatalogHeading extends StatelessWidget {
  const _CatalogHeading({required this.state});

  final AnimeListState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final heading = switch (state.sort) {
      AnimeListSortOption.popularity => l10n.animeListHeadingPopularity,
      AnimeListSortOption.score => l10n.animeListHeadingScore,
      AnimeListSortOption.airedOn => l10n.animeListHeadingAiredOn,
    };
    final filters = animeListFilterLabels(l10n, state.filters);
    final compact = WindowSizeClass.of(context).isCompact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DitherSwitcher(
          child: Column(
            key: ValueKey((heading, filters.join())),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DisplayTitle(
                heading,
                maxSize: compact ? 56 : 144,
                minSize: 32,
                maxLines: 1,
              ),
              if (filters.isNotEmpty) ...[
                const SizedBox(height: 12),
                CaptionText(filters.join(' · ')),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.bloc});

  final AnimeListBloc bloc;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return RetryView(
      message: l10n.animeListLoadError,
      onRetry: () => bloc.add(const AnimeListInitialRetryRequested()),
    );
  }
}

/// Every filter in force, in the order the filter sheet shows them.
List<String> animeListFilterLabels(
  AppLocalizations l10n,
  AnimeListFilters filters,
) => [
  for (final kind in filters.kinds) animeKindFilterLabel(l10n, kind),
  for (final status in filters.statuses) animeStatusFilterLabel(l10n, status),
  for (final status in UserRateStatus.values)
    if (filters.myList.contains(status)) userRateStatusLabel(l10n, status),
  if (filters.hideCompleted) l10n.animeListHideCompleted,
  for (final genre in filters.genres) animeGenreLabel(l10n, genre),
  for (final season in filters.seasons) seasonFilterLabel(l10n, season),
  for (final rating in AnimeRatingFilter.values)
    if (filters.ratings.contains(rating)) animeRatingFilterLabel(rating),
  for (final duration in AnimeDurationFilter.values)
    if (filters.durations.contains(duration))
      animeDurationFilterLabel(l10n, duration),
];
