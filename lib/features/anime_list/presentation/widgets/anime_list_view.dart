import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_state.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_card.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_list_criteria_sheet.dart';
import 'package:iris/features/anime_list/presentation/widgets/continue_watching_row.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/search_field.dart';
import 'package:iris/shared/widgets/search_toolbar.dart';

const _gridSpacing = 16.0;

class AnimeListView extends StatefulWidget {
  const AnimeListView({super.key});

  @override
  State<AnimeListView> createState() => _AnimeListViewState();
}

class _AnimeListViewState extends State<AnimeListView> {
  static const _loadMoreThreshold = 600.0;
  static const _minCardWidth = 320.0;
  static const _searchDebounceDuration = Duration(milliseconds: 400);

  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  Timer? _searchDebounceTimer;
  bool _viewportFillCheckScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final remainingScrollExtent =
        _scrollController.position.maxScrollExtent - _scrollController.offset;

    if (remainingScrollExtent <= _loadMoreThreshold) {
      context.read<AnimeListBloc>().add(const AnimeListNextPageRequested());
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      final query = value.trim();

      if (query.isEmpty) {
        context.read<AnimeListBloc>().add(const AnimeListSearchCleared());
        return;
      }

      context.read<AnimeListBloc>().add(AnimeListSearchChanged(query));
    });
  }

  void _scheduleViewportFillCheck(AnimeListState state) {
    if (_viewportFillCheckScheduled ||
        !state.hasMore ||
        state.isLoadingMore ||
        state.errorType != AnimeListErrorType.none) {
      return;
    }

    // Wide windows can fit a whole page without scrolling, which would never
    // trigger the scroll listener; request the next page in that case.
    _viewportFillCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportFillCheckScheduled = false;
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final position = _scrollController.position;
      if (position.hasContentDimensions && position.maxScrollExtent <= 0) {
        context.read<AnimeListBloc>().add(const AnimeListNextPageRequested());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = adaptiveColumnCount(
          availableWidth: constraints.maxWidth,
          minItemWidth: _minCardWidth,
          spacing: _gridSpacing,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SearchControls(
              controller: _searchController,
              onChanged: _onSearchChanged,
              isWide: constraints.maxWidth >= WindowSizeClass.mediumMinWidth,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<AnimeListBloc, AnimeListState>(
                builder: (context, state) {
                  if (state.isInitialLoading) {
                    return const _LoadingState();
                  }

                  if (state.errorType == AnimeListErrorType.initial &&
                      !state.hasLoadedOnce) {
                    return const _FailureState();
                  }

                  if (state.hasLoadedOnce && state.items.isEmpty) {
                    return _EmptyState(query: state.query);
                  }

                  _scheduleViewportFillCheck(state);
                  return _AnimeGrid(
                    state: state,
                    columns: columns,
                    controller: _scrollController,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchControls extends StatelessWidget {
  const _SearchControls({
    required this.controller,
    required this.onChanged,
    required this.isWide,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SearchToolbar(
      searchField: SearchField(
        controller: controller,
        hintText: l10n.animeListSearchHint,
        onChanged: onChanged,
      ),
      actionIcon: Icons.tune,
      actionLabel: l10n.animeListFilterSortButton,
      onAction: () => showAnimeListCriteriaSheet(context),
      isWide: isWide,
    );
  }
}

class _AnimeGrid extends StatelessWidget {
  const _AnimeGrid({
    required this.state,
    required this.columns,
    required this.controller,
  });

  final AnimeListState state;
  final int columns;
  final ScrollController controller;

  bool get _hasFooter =>
      state.isLoadingMore || state.errorType == AnimeListErrorType.loadMore;

  @override
  Widget build(BuildContext context) {
    final items = state.items;
    final rowCount = (items.length / columns).ceil();
    // The catalog's own results take over while searching.
    final continueItems = state.query.isEmpty
        ? continueWatchingItems(context.watchWatchProgress())
        : const <WatchProgress>[];
    final headerCount = continueItems.isEmpty ? 0 : 1;

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: headerCount + rowCount + (_hasFooter ? 1 : 0),
      separatorBuilder: (context, index) =>
          const SizedBox(height: _gridSpacing),
      itemBuilder: (context, index) {
        if (index < headerCount) {
          return ContinueWatchingRow(items: continueItems);
        }
        index -= headerCount;
        if (index >= rowCount) {
          return _ListFooter(state: state);
        }

        final start = index * columns;
        final end = math.min(start + columns, items.length);

        return AdaptiveGridRow(
          columns: columns,
          spacing: _gridSpacing,
          children: [
            for (final item in items.sublist(start, end))
              AnimeCard(
                item: item,
                onTap: () => context.pushNamed(
                  'anime-details',
                  pathParameters: {'id': item.id},
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(l10n.animeListLoading),
        ],
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(l10n.animeListLoadError, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                context.read<AnimeListBloc>().add(
                  const AnimeListInitialRetryRequested(),
                );
              },
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.read<AnimeListBloc>().state;
    final message = query.isNotEmpty
        ? l10n.animeListSearchEmpty
        : state.filters.hasAny
        ? l10n.animeListCriteriaEmpty
        : l10n.animeListEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.state});

  final AnimeListState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorType == AnimeListErrorType.loadMore) {
      final l10n = AppLocalizations.of(context);

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: Text(l10n.animeListLoadMoreError)),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {
                    context.read<AnimeListBloc>().add(
                      const AnimeListNextPageRequested(),
                    );
                  },
                  child: Text(l10n.commonRetry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
