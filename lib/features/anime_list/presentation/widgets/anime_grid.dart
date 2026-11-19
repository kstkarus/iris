import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_item.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_state.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_card.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// Covers sit close side by side; rows get more air, so each title reads
/// with its own cover.
const _columnSpacing = 16.0;
const _rowSpacing = 28.0;

/// Cards of [bloc]'s list in rows of [columns], paged as it scrolls. While
/// the first page loads the rows are card-shaped noise, and each row
/// develops out of it when the page arrives. [header] sits above the
/// first row, [headerGap] away.
class AnimeGrid extends StatefulWidget {
  const AnimeGrid({
    required this.bloc,
    required this.state,
    required this.columns,
    required this.controller,
    this.header,
    this.contentPadding = EdgeInsets.zero,
    this.onOpenAnime,
    super.key,
  });

  static const headerGap = 28.0;
  static const columnSpacing = _columnSpacing;

  final AnimeListBloc bloc;
  final AnimeListState state;
  final int columns;
  final ScrollController controller;
  final Widget? header;
  final EdgeInsetsGeometry contentPadding;
  final VoidCallback? onOpenAnime;

  @override
  State<AnimeGrid> createState() => _AnimeGridState();
}

class _AnimeGridState extends State<AnimeGrid> {
  static const _loadMoreThreshold = 600.0;

  /// Rows of stand-in cards shown as noise while the first page loads.
  static const _standInRows = 3;

  ScrollableState? _scrollable;
  bool _prefetchCheckScheduled = false;

  void _onScroll() {
    if (!mounted || !_canLoadMore) return;
    final scrollable = _scrollable;
    if (scrollable == null || !scrollable.mounted) return;
    final position = scrollable.position;
    if (position.hasContentDimensions &&
        position.extentAfter <= _loadMoreThreshold) {
      widget.bloc.add(const AnimeListNextPageRequested());
    }
  }

  bool get _canLoadMore {
    final state = widget.bloc.state;
    return identical(widget.state, state) &&
        state.hasLoadedOnce &&
        !state.isInitialLoading &&
        state.hasMore &&
        !state.isLoadingMore &&
        state.errorType == AnimeListErrorType.none &&
        TickerMode.valuesOf(context).enabled;
  }

  void _schedulePrefetchCheck() {
    if (_prefetchCheckScheduled || !_canLoadMore) return;

    // Layout and resize need the same buffer as scrolling, including when
    // a page only slightly exceeds the viewport. Read fresh metrics and state.
    _prefetchCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchCheckScheduled = false;
      _onScroll();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    _schedulePrefetchCheck();
    final state = widget.state;
    final columns = widget.columns;
    final header = widget.header;
    final loading = state.isInitialLoading;
    final items = loading
        ? [
            for (var i = 0; i < columns * _standInRows; i++)
              _standInItems[i % _standInItems.length],
          ]
        : state.items;
    final loadingLabel = AppLocalizations.of(context).animeListLoading;
    final rowCount = (items.length / columns).ceil();
    final first = header == null ? 0 : 1;

    return NotificationListener<Notification>(
      onNotification: (notification) {
        switch (notification) {
          case ScrollMetricsNotification(depth: 0, :final context):
            _scrollable = Scrollable.maybeOf(context);
            _schedulePrefetchCheck();
          case ScrollUpdateNotification(depth: 0):
            _onScroll();
        }
        return false;
      },
      child: CustomScrollView(
        controller: widget.controller,
        semanticChildCount: first + rowCount,
        slivers: [
          SliverList.separated(
            itemCount: first + rowCount,
            separatorBuilder: (context, index) => SizedBox(
              height: index < first ? AnimeGrid.headerGap : _rowSpacing,
            ),
            itemBuilder: (context, index) {
              if (index < first) return header;
              index -= first;
              final start = index * columns;
              final end = math.min(start + columns, items.length);

              // Each row develops out of its own noise when the page arrives.
              return Padding(
                padding: widget.contentPadding,
                child: AppSkeleton(
                  enabled: loading,
                  semanticLabel: index == 0 ? loadingLabel : null,
                  child: AdaptiveGridRow(
                    columns: columns,
                    spacing: _columnSpacing,
                    children: [
                      for (final item in items.sublist(start, end))
                        AnimeCard(
                          item: item,
                          onTap: () {
                            widget.onOpenAnime?.call();
                            context.pushNamed(
                              'anime-details',
                              pathParameters: {'id': item.anime.id},
                              extra: AnimeDetailsPreview.fromSummary(
                                item.anime,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Its transition stays mounted when new rows shift the end.
          SliverToBoxAdapter(
            child: Padding(
              padding: widget.contentPadding.add(
                const EdgeInsets.only(bottom: 24),
              ),
              child: PagingFooter(
                topSpacing: rowCount > 0
                    ? _rowSpacing
                    : header != null
                    ? AnimeGrid.headerGap
                    : 0,
                loadingMore: state.isLoadingMore,
                failed: state.errorType == AnimeListErrorType.loadMore,
                failedMessage: AppLocalizations.of(
                  context,
                ).animeListLoadMoreError,
                onRetry: () =>
                    widget.bloc.add(const AnimeListNextPageRequested()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stand-in cards: the noise takes the shape of typical cards, with names
/// of different lengths so the rows do not repeat one shape.
const _standInItems = [
  AnimeListItem(
    anime: AnimeSummary(
      id: '',
      name: 'An anime title',
      russian: 'Its name in Russian',
      kind: 'tv',
      score: 8.5,
      status: 'released',
      episodes: 24,
      episodesAired: 24,
      airedOn: '2020-01-01',
      posterUrl: '',
    ),
  ),
  AnimeListItem(
    anime: AnimeSummary(
      id: '',
      name: 'A rather longer anime title',
      russian: 'Name',
      kind: 'movie',
      score: 7.9,
      status: 'released',
      episodes: 1,
      episodesAired: 1,
      airedOn: '2018-01-01',
      posterUrl: '',
    ),
  ),
  AnimeListItem(
    anime: AnimeSummary(
      id: '',
      name: 'Title',
      russian: 'A longer name in Russian',
      kind: 'tv',
      score: 8.1,
      status: 'ongoing',
      episodes: 12,
      episodesAired: 6,
      airedOn: '2026-01-01',
      posterUrl: '',
    ),
  ),
];
