import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_state.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_card.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

class AnimeListView extends StatefulWidget {
  const AnimeListView({super.key});

  @override
  State<AnimeListView> createState() => _AnimeListViewState();
}

class _AnimeListViewState extends State<AnimeListView> {
  static const _loadMoreThreshold = 600.0;
  static const _searchDebounceDuration = Duration(milliseconds: 400);

  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  Timer? _searchDebounceTimer;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.animeListSearchHint,
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _openCriteriaSheet(context),
            icon: const Icon(Icons.tune),
            label: Text(l10n.animeListFilterSortButton),
          ),
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

              return ListView.separated(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                itemCount: _itemCount(state),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  if (index >= state.items.length) {
                    return _ListFooter(state: state);
                  }

                  final item = state.items[index];

                  return AnimeCard(
                    item: item,
                    onTap: () => context.pushNamed(
                      'anime-details',
                      pathParameters: {'id': item.id},
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  int _itemCount(AnimeListState state) {
    if (state.isLoadingMore || state.errorType == AnimeListErrorType.loadMore) {
      return state.items.length + 1;
    }

    return state.items.length;
  }

  Future<void> _openCriteriaSheet(BuildContext context) async {
    final bloc = context.read<AnimeListBloc>();
    final state = bloc.state;
    var draftSort = state.sort;
    var draftKinds = Set<AnimeKindFilter>.from(state.filters.kinds);
    var draftStatuses = Set<AnimeStatusFilter>.from(state.filters.statuses);
    final l10n = AppLocalizations.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.9,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.animeListFilterSortTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.animeListSortSectionTitle,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: AnimeListSortOption.values
                                    .map(
                                      (sort) => ChoiceChip(
                                        label: Text(
                                          _formatSortLabel(l10n, sort),
                                        ),
                                        selected: draftSort == sort,
                                        onSelected: (_) {
                                          setModalState(() {
                                            draftSort = sort;
                                          });
                                        },
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                l10n.animeListTypeSectionTitle,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: AnimeKindFilter.values
                                    .map(
                                      (kind) => FilterChip(
                                        label: Text(
                                          _formatKindLabel(l10n, kind),
                                        ),
                                        selected: draftKinds.contains(kind),
                                        onSelected: (selected) {
                                          setModalState(() {
                                            if (selected) {
                                              draftKinds.add(kind);
                                            } else {
                                              draftKinds.remove(kind);
                                            }
                                          });
                                        },
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                l10n.animeListStatusSectionTitle,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: AnimeStatusFilter.values
                                    .map(
                                      (status) => FilterChip(
                                        label: Text(
                                          _formatStatusLabel(l10n, status),
                                        ),
                                        selected: draftStatuses.contains(
                                          status,
                                        ),
                                        onSelected: (selected) {
                                          setModalState(() {
                                            if (selected) {
                                              draftStatuses.add(status);
                                            } else {
                                              draftStatuses.remove(status);
                                            }
                                          });
                                        },
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                draftSort = AnimeListSortOption.popularity;
                                draftKinds = <AnimeKindFilter>{};
                                draftStatuses = <AnimeStatusFilter>{};
                              });
                            },
                            child: Text(l10n.animeListResetButton),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () {
                              bloc.add(
                                AnimeListCriteriaApplied(
                                  sort: draftSort,
                                  filters: AnimeListFilters(
                                    kinds: draftKinds,
                                    statuses: draftStatuses,
                                  ),
                                ),
                              );
                              Navigator.of(context).pop();
                            },
                            child: Text(l10n.animeListApplyButton),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
