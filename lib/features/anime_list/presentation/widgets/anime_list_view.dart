import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_state.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_search_bloc.dart';
import 'package:iris/features/anime_list/presentation/cubit/search_history_cubit.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_grid.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_list_criteria_sheet.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_list_filter_chips.dart';
import 'package:iris/features/anime_list/presentation/widgets/continue_watching_button.dart';
import 'package:iris/features/anime_list/presentation/widgets/continue_watching_row.dart';
import 'package:iris/features/anime_list/presentation/widgets/recent_searches.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/bayer_mask.dart';
import 'package:iris/shared/widgets/active_layer.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/display_title.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/dither_transition.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/search_field.dart';
import 'package:iris/shared/widgets/search_toolbar.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// The catalog under a search field.
///
/// Focusing the field shows recent queries; typing shows search results.
/// Back or Escape restores the catalog in place.
/// Results live in their own [AnimeSearchBloc].
class AnimeListView extends StatefulWidget {
  const AnimeListView({this.detailsRepository, super.key});

  final AnimeDetailsRepository? detailsRepository;

  @override
  State<AnimeListView> createState() => _AnimeListViewState();
}

class _AnimeListViewState extends State<AnimeListView>
    with SingleTickerProviderStateMixin {
  static const _minCardWidth = 150.0;
  static const _maxColumns = 8;
  static const _searchDebounceDuration = Duration(milliseconds: 400);

  final _catalogScroll = ScrollController();
  final _resultsScroll = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  /// 0 shows the catalog, 1 the search results.
  late final AnimationController _results = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Timer? _searchDebounceTimer;
  bool _searching = false;

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
  }

  void _enterSearch() {
    if (_searching) return;
    setState(() => _searching = true);

    _animateSearch(true);
  }

  void _recordQuery(String query) =>
      context.read<SearchHistoryCubit?>()?.record(query);

  void _submitSearch(String query) {
    _searchDebounceTimer?.cancel();
    _recordQuery(query);
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      context.read<AnimeSearchBloc>().add(AnimeListSearchChanged(trimmed));
    }
    _searchFocus.unfocus();
  }

  void _selectRecent(String query) {
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _recordQuery(query);
    _searchDebounceTimer?.cancel();
    context.read<AnimeSearchBloc>().add(AnimeListSearchChanged(query));
  }

  void _exitSearch() {
    if (!_searching) return;
    _recordQuery(_searchController.text);
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    context.read<AnimeSearchBloc>().add(const AnimeListSearchCleared());
    setState(() => _searching = false);
    _animateSearch(false);
    _searchFocus.unfocus();
  }

  void _animateSearch(bool show) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _results.value = show ? 1 : 0;
    } else if (show) {
      _results.forward();
    } else {
      _results.reverse();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    final query = value.trim();
    // An emptied field brings recent queries back at once.
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
            final inset = math.max(
              WindowSizeClass.of(context).pageMargin,
              (constraints.maxWidth - AdaptiveContentWidth.page) / 2,
            );
            final contentPadding = EdgeInsets.symmetric(horizontal: inset);
            final contentWidth = constraints.maxWidth - inset * 2;
            final columns = adaptiveColumnCount(
              availableWidth: contentWidth,
              minItemWidth: _minCardWidth,
              spacing: AnimeGrid.columnSpacing,
              maxColumns: _maxColumns,
            ).clamp(2, _maxColumns);
            final isWide = contentWidth >= WindowSizeClass.mediumMinWidth;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape):
                        _exitSearch,
                  },
                  child: Padding(
                    padding: contentPadding,
                    child: _SearchControls(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      onSubmitted: _submitSearch,
                      isWide: isWide,
                      onCancel: _searching ? _exitSearch : null,
                      detailsRepository: widget.detailsRepository,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _Layers(
                    results: _results,
                    searching: _searching,
                    catalog: _CatalogPane(
                      columns: columns,
                      controller: _catalogScroll,
                      padding: contentPadding,
                    ),
                    search: _ResultsPane(
                      columns: columns,
                      controller: _resultsScroll,
                      onRecent: _selectRecent,
                      padding: contentPadding,
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

class _SearchControls extends StatefulWidget {
  const _SearchControls({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.isWide,
    required this.onCancel,
    required this.detailsRepository,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final bool isWide;
  final VoidCallback? onCancel;
  final AnimeDetailsRepository? detailsRepository;

  @override
  State<_SearchControls> createState() => _SearchControlsState();
}

class _SearchControlsState extends State<_SearchControls>
    with SingleTickerProviderStateMixin {
  late final AnimationController _historyController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final CurvedAnimation _historyCurve = CurvedAnimation(
    parent: _historyController,
    curve: Curves.easeOutCubic,
  );
  bool _initialized = false;
  bool _hasHistory = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final hasHistory = continueWatchingItems(
      context.watchWatchProgress(),
    ).isNotEmpty;
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (!_initialized) {
      _initialized = true;
      _hasHistory = hasHistory;
      _historyController.value = hasHistory ? 1 : 0;
      return;
    }
    if (hasHistory == _hasHistory) return;
    _hasHistory = hasHistory;
    if (!animate) {
      _historyController.value = hasHistory ? 1 : 0;
    } else if (hasHistory) {
      _historyController.forward();
    } else {
      _historyController.reverse();
    }
  }

  @override
  void dispose() {
    _historyCurve.dispose();
    _historyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final narrowed = context.select<AnimeListBloc, bool>(
      (bloc) =>
          bloc.state.filters.hasAny ||
          bloc.state.sort != AnimeListSortOption.popularity,
    );
    final count = context.select<AnimeListBloc, int>(
      (bloc) => bloc.state.filters.activeCount,
    );
    return AnimatedBuilder(
      animation: _historyController,
      builder: (context, _) {
        final showHistory = _hasHistory || !_historyController.isDismissed;
        final history = !showHistory
            ? null
            : FadeTransition(
                opacity: _historyCurve,
                child: SizeTransition(
                  sizeFactor: _historyCurve,
                  axis: Axis.horizontal,
                  alignment: AlignmentDirectional.centerEnd,
                  child: IgnorePointer(
                    ignoring: !_hasHistory,
                    child: ExcludeSemantics(
                      excluding: !_hasHistory,
                      child: ContinueWatchingButton(
                        repository: widget.detailsRepository,
                      ),
                    ),
                  ),
                ),
              );
        return SearchToolbar(
          searchField: SearchField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            hintText: l10n.animeListSearchHint,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            onCancel: widget.onCancel,
          ),
          actionIcon: PixelGlyph.tune,
          actionLabel: l10n.animeListFilterSortButton,
          actionActive: narrowed,
          actionCount: count,
          onAction: () => showAnimeListCriteriaSheet(
            context,
            search: widget.controller.text.trim(),
          ),
          isWide: widget.isWide,
          trailingAction: history,
        );
      },
    );
  }
}

/// The catalog with the search results over it. The results develop over
/// the catalog cell by cell and go the same way; the catalog stays mounted
/// underneath, scroll position and all.
class _Layers extends StatelessWidget {
  const _Layers({
    required this.results,
    required this.searching,
    required this.catalog,
    required this.search,
  });

  final Animation<double> results;
  final bool searching;
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
                child: ActiveLayer(
                  active: !searching,
                  child: BayerMasked(open: open, inverse: true, child: catalog),
                ),
              ),
            ),
            if (open > 0)
              ActiveLayer(
                active: searching,
                child: BayerMasked(open: open, child: search),
              ),
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
    required this.padding,
  });

  final int columns;
  final ScrollController controller;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnimeListBloc, AnimeListState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context);
        final bloc = context.read<AnimeListBloc>();
        final heading = _CatalogHeading(state: state, padding: padding);
        Widget? message;
        if (!state.isInitialLoading) {
          if (state.errorType == AnimeListErrorType.initial &&
              !state.hasLoadedOnce) {
            message = _FailureState(bloc: bloc);
          } else if (state.hasLoadedOnce && state.items.isEmpty) {
            message = MessageView(
              message: state.filters.hasAny
                  ? l10n.animeListCriteriaEmpty
                  : l10n.animeListEmpty,
              action: state.filters.hasAny ? _ResetFiltersButton() : null,
            );
          }
        }
        final Widget child;
        if (message != null) {
          child = CustomScrollView(
            key: ValueKey(
              'catalog_message_${state.errorType}_${state.filters.hasAny}',
            ),
            primary: false,
            slivers: [
              SliverToBoxAdapter(child: heading),
              const SliverToBoxAdapter(
                child: SizedBox(height: AnimeGrid.headerGap),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(padding: padding, child: message),
              ),
            ],
          );
        } else {
          child = AnimeGrid(
            key: const ValueKey('catalog_grid'),
            bloc: bloc,
            state: state,
            columns: columns,
            controller: controller,
            header: heading,
            contentPadding: padding,
          );
        }

        return DitherSwitcher(
          expand: true,
          duration: const Duration(milliseconds: 240),
          child: child,
        );
      },
    );
  }
}

/// Search results speak for themselves: no header over them.
class _ResultsPane extends StatelessWidget {
  const _ResultsPane({
    required this.columns,
    required this.controller,
    required this.onRecent,
    required this.padding,
  });

  final ValueChanged<String> onRecent;

  final int columns;
  final ScrollController controller;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BlocBuilder<AnimeListBloc, AnimeListState>(
          buildWhen: (before, after) => before.filters != after.filters,
          builder: (context, state) => AnimeListFilterChips(
            filters: state.filters,
            padding: padding.add(const EdgeInsets.only(bottom: 16)),
          ),
        ),
        Expanded(
          child: Padding(
            padding: padding,
            child: BlocBuilder<AnimeSearchBloc, AnimeListState>(
              builder: (context, state) {
                return DitherSwitcher(
                  expand: true,
                  child: state.query.isEmpty
                      ? RecentSearches(
                          key: const ValueKey('recent'),
                          onSelected: onRecent,
                        )
                      : _SearchResults(
                          key: const ValueKey('results'),
                          state: state,
                          columns: columns,
                          controller: controller,
                        ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.state,
    required this.columns,
    required this.controller,
    super.key,
  });

  final AnimeListState state;
  final int columns;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AnimeSearchBloc>();
    final Widget child;
    if (!state.isInitialLoading &&
        state.errorType == AnimeListErrorType.initial &&
        !state.hasLoadedOnce) {
      child = _FailureState(key: const ValueKey('search_failure'), bloc: bloc);
    } else if (!state.isInitialLoading &&
        state.hasLoadedOnce &&
        state.items.isEmpty) {
      child = MessageView(
        key: ValueKey('search_empty_${state.filters.hasAny}'),
        message: AppLocalizations.of(context).animeListSearchEmpty,
        icon: PixelIcon(
          PixelGlyph.search,
          size: 42,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        action: state.filters.hasAny ? _ResetFiltersButton() : null,
      );
    } else {
      child = AnimeGrid(
        key: const ValueKey('search_grid'),
        bloc: bloc,
        state: state,
        columns: columns,
        controller: controller,
        onOpenAnime: () =>
            context.read<SearchHistoryCubit?>()?.record(state.query),
      );
    }
    return DitherSwitcher(
      expand: true,
      duration: const Duration(milliseconds: 240),
      child: child,
    );
  }
}

/// The catalog's one big word: what the list below is, by its order.
/// Removable filters follow the heading.
class _CatalogHeading extends StatelessWidget {
  const _CatalogHeading({required this.state, required this.padding});

  final AnimeListState state;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final heading = switch (state.sort) {
      AnimeListSortOption.popularity => l10n.animeListHeadingPopularity,
      AnimeListSortOption.score => l10n.animeListHeadingScore,
      AnimeListSortOption.airedOn => l10n.animeListHeadingAiredOn,
    };
    final compact = WindowSizeClass.of(context).isCompact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: padding,
          child: DitherSwitcher(
            child: DisplayTitle(
              heading,
              key: ValueKey(heading),
              fontFamily: 'Medeo Pixel Grid',
              maxSize: compact ? 48 : 72,
              minSize: 32,
              maxLines: 1,
            ),
          ),
        ),
        AnimeListFilterChips(
          filters: state.filters,
          padding: padding.add(const EdgeInsets.only(top: 16)),
        ),
      ],
    );
  }
}

class _ResetFiltersButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: () => context.read<AnimeListBloc>().add(
      const AnimeListCriteriaApplied(filters: AnimeListFilters()),
    ),
    child: Text(AppLocalizations.of(context).animeListResetFilters),
  );
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.bloc, super.key});

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
