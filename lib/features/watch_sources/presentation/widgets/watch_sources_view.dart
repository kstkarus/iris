import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_state.dart';
import 'package:iris/features/watch_sources/presentation/models/watch_sources_sort_option.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

class WatchSourcesView extends StatelessWidget {
  const WatchSourcesView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WatchSourcesCubit, WatchSourcesState>(
      builder: (context, state) {
        return switch (state) {
          WatchSourcesInitial() ||
          WatchSourcesLoading() => const _LoadingState(),
          WatchSourcesLoaded() => _LoadedState(state: state),
          WatchSourcesEmpty() => const _EmptyState(),
          WatchSourcesFailure() => const _FailureState(),
        };
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
          Text(l10n.watchSourcesLoading),
        ],
      ),
    );
  }
}

class _LoadedState extends StatelessWidget {
  const _LoadedState({required this.state});

  final WatchSourcesLoaded state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: TextEditingController.fromValue(
            TextEditingValue(
              text: state.searchQuery,
              selection: TextSelection.collapsed(
                offset: state.searchQuery.length,
              ),
            ),
          ),
          onChanged: context.read<WatchSourcesCubit>().updateSearchQuery,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.watchSourcesSearchHint,
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _openSortSheet(context),
            icon: const Icon(Icons.sort),
            label: Text(l10n.watchSourcesSortButton),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: state.visibleItems.isEmpty
              ? const _SearchEmptyState()
              : ListView.separated(
                  itemCount: state.visibleItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _WatchSourceCard(
                      item: state.visibleItems[index],
                      animeId: context.read<WatchSourcesCubit>().animeId,
                      animeEnglishTitle: context
                          .read<WatchSourcesCubit>()
                          .animeEnglishTitle,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _openSortSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<WatchSourcesCubit>();
    var selectedOption = state.sortOption;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.watchSourcesSortSheetTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      RadioGroup<WatchSourcesSortOption>(
                        groupValue: selectedOption,
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setModalState(() {
                            selectedOption = value;
                          });
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: WatchSourcesSortOption.values
                              .map(
                                (option) =>
                                    RadioListTile<WatchSourcesSortOption>(
                                      contentPadding: EdgeInsets.zero,
                                      value: option,
                                      title: Text(
                                        _formatSortLabel(l10n, option),
                                      ),
                                    ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            cubit.updateSortOption(selectedOption);
                            Navigator.of(context).pop();
                          },
                          child: Text(l10n.watchSourcesSortApplyButton),
                        ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.watchSourcesEmpty, textAlign: TextAlign.center),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.watchSourcesSearchEmpty, textAlign: TextAlign.center),
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
            Text(l10n.watchSourcesLoadError, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.read<WatchSourcesCubit>().loadSources(),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchSourceCard extends StatelessWidget {
  const _WatchSourceCard({
    required this.item,
    required this.animeId,
    required this.animeEnglishTitle,
  });

  final WatchSourceItem item;
  final String animeId;
  final String animeEnglishTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.category,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(label: '${l10n.watchSourcesSizeLabel}: ${item.size}'),
                _InfoChip(label: '${l10n.watchSourcesTimeLabel}: ${item.time}'),
                _InfoChip(
                  label: '${l10n.watchSourcesSeedersLabel}: ${item.seeders}',
                ),
                _InfoChip(
                  label: '${l10n.watchSourcesLeechersLabel}: ${item.leechers}',
                ),
                _InfoChip(
                  label:
                      '${l10n.watchSourcesDownloadsLabel}: ${item.downloads}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _LinkBlock(label: l10n.watchSourcesPageLinkLabel, value: item.link),
            const SizedBox(height: 12),
            _LinkBlock(
              label: l10n.watchSourcesTorrentLinkLabel,
              value: item.torrent,
            ),
            const SizedBox(height: 12),
            _LinkBlock(
              label: l10n.watchSourcesMagnetLinkLabel,
              value: item.magnet,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  context.pushNamed(
                    'anime-player-files',
                    pathParameters: {'id': animeId},
                    extra: AnimePlayerSourceArgs(
                      animeId: animeId,
                      animeTitle: animeEnglishTitle,
                      sourceTitle: item.title,
                      magnet: item.magnet,
                    ),
                  );
                },
                child: Text(l10n.playerOpenButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _LinkBlock extends StatelessWidget {
  const _LinkBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
        ),
      ],
    );
  }
}

String _formatSortLabel(AppLocalizations l10n, WatchSourcesSortOption option) {
  switch (option) {
    case WatchSourcesSortOption.seedersDesc:
      return l10n.watchSourcesSortSeeders;
    case WatchSourcesSortOption.publishedAtDesc:
      return l10n.watchSourcesSortPublishedAt;
    case WatchSourcesSortOption.downloadsDesc:
      return l10n.watchSourcesSortDownloads;
    case WatchSourcesSortOption.titleAsc:
      return l10n.watchSourcesSortTitle;
  }
}
