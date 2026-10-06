import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_state.dart';
import 'package:iris/features/watch_sources/presentation/models/watch_sources_sort_option.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/torrent/torrent_key.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/show_adaptive_sheet.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/search_field.dart';
import 'package:iris/shared/widgets/search_toolbar.dart';

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
    final watchedKeys = {
      for (final progress in context.watchWatchProgress()) progress.torrentKey,
    };
    final items = _watchedFirst(state.visibleItems, watchedKeys);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SearchControls(
              initialQuery: state.searchQuery,
              isWide: constraints.maxWidth >= WindowSizeClass.mediumMinWidth,
              onSort: () => _openSortSheet(context),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? const _SearchEmptyState()
                  : _SourcesList(items: items, watchedKeys: watchedKeys),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openSortSheet(BuildContext context) {
    final cubit = context.read<WatchSourcesCubit>();

    return showAdaptiveSheet<void>(
      context: context,
      builder: (_) => _SortSheet(
        initialOption: state.sortOption,
        onApply: cubit.updateSortOption,
      ),
    );
  }
}

class _SearchControls extends StatefulWidget {
  const _SearchControls({
    required this.initialQuery,
    required this.isWide,
    required this.onSort,
  });

  final String initialQuery;
  final bool isWide;
  final VoidCallback onSort;

  @override
  State<_SearchControls> createState() => _SearchControlsState();
}

class _SearchControlsState extends State<_SearchControls> {
  // Owned here: recreating it on every rebuild would move the caret to the
  // end while people edit the middle of the query.
  late final _controller = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SearchToolbar(
      searchField: SearchField(
        controller: _controller,
        hintText: l10n.watchSourcesSearchHint,
        onChanged: context.read<WatchSourcesCubit>().updateSearchQuery,
      ),
      actionIcon: Icons.sort,
      actionLabel: l10n.watchSourcesSortButton,
      onAction: widget.onSort,
      isWide: widget.isWide,
    );
  }
}

class _SortSheet extends StatefulWidget {
  const _SortSheet({required this.initialOption, required this.onApply});

  final WatchSourcesSortOption initialOption;
  final ValueChanged<WatchSourcesSortOption> onApply;

  @override
  State<_SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<_SortSheet> {
  late WatchSourcesSortOption _selectedOption = widget.initialOption;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
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
              groupValue: _selectedOption,
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _selectedOption = value;
                });
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in WatchSourcesSortOption.values)
                    RadioListTile<WatchSourcesSortOption>(
                      contentPadding: EdgeInsets.zero,
                      value: option,
                      title: Text(_formatSortLabel(l10n, option)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.onApply(_selectedOption);
                  Navigator.of(context).pop();
                },
                child: Text(l10n.watchSourcesSortApplyButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Releases the user already streamed come first, keeping the chosen sort
/// order inside both groups.
List<WatchSourceItem> _watchedFirst(
  List<WatchSourceItem> items,
  Set<String> watchedKeys,
) {
  if (watchedKeys.isEmpty) return items;
  bool isWatched(WatchSourceItem item) =>
      watchedKeys.contains(torrentKeyFromMagnet(item.magnet));
  return [
    ...items.where(isWatched),
    ...items.where((item) => !isWatched(item)),
  ];
}

/// Releases are text, so they read best as a list: tapping a row streams
/// it, the trailing button downloads it.
class _SourcesList extends StatelessWidget {
  const _SourcesList({required this.items, required this.watchedKeys});

  final List<WatchSourceItem> items;
  final Set<String> watchedKeys;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WatchSourcesCubit>();
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AdaptiveContentWidth.list),
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: items.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (context, index) {
            final item = items[index];
            return _WatchSourceRow(
              item: item,
              watched: watchedKeys.contains(torrentKeyFromMagnet(item.magnet)),
              animeId: cubit.animeId,
              animeEnglishTitle: cubit.animeEnglishTitle,
            );
          },
        ),
      ),
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

class _WatchSourceRow extends StatelessWidget {
  const _WatchSourceRow({
    required this.item,
    required this.watched,
    required this.animeId,
    required this.animeEnglishTitle,
  });

  final WatchSourceItem item;

  /// The user streamed this release before.
  final bool watched;
  final String animeId;
  final String animeEnglishTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListTile(
      key: const Key('watch_source_watch_button'),
      contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        item.title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text.rich(
          key: watched ? const Key('watch_source_used_badge') : null,
          TextSpan(
            children: [
              if (watched) ...[
                TextSpan(
                  text: l10n.watchSourceUsedBadge,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' · '),
              ],
              TextSpan(text: _formatSourceMeta(l10n, item)),
            ],
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      trailing: IconButton(
        key: const Key('watch_source_download_button'),
        tooltip: l10n.downloadsOpenButton,
        icon: const Icon(Icons.download_outlined),
        onPressed: () => _openDownload(context),
      ),
      onTap: () => _openStreaming(context),
    );
  }

  void _openStreaming(BuildContext context) {
    context.pushNamed(
      'torrent-stream-files',
      extra: AnimePlayerSourceArgs(
        animeId: animeId,
        animeTitle: animeEnglishTitle,
        sourceTitle: item.title,
        magnet: item.magnet,
      ),
    );
  }

  void _openDownload(BuildContext context) {
    context.pushNamed(
      'torrent-download-files',
      extra: DownloadSelectionArgs(
        animeId: animeId,
        animeTitle: animeEnglishTitle,
        sourceTitle: item.title,
        magnet: item.magnet,
      ),
    );
  }
}

/// Size, swarm, popularity, date and category in one secondary line.
String _formatSourceMeta(AppLocalizations l10n, WatchSourceItem item) {
  final numbers = NumberFormat.decimalPattern(l10n.localeName);
  final published = DateTime.tryParse(item.time);
  final category = item.category.replaceFirst(RegExp(r'^Anime\s*-\s*'), '');
  return [
    if (item.size.isNotEmpty) item.size,
    l10n.watchSourceSeeders(numbers.format(item.seeders), item.seeders),
    l10n.watchSourceLeechers(numbers.format(item.leechers), item.leechers),
    l10n.watchSourceDownloads(numbers.format(item.downloads), item.downloads),
    if (published != null)
      DateFormat.yMMMd(l10n.localeName).format(published)
    else if (item.time.isNotEmpty)
      item.time,
    if (category.isNotEmpty) category,
  ].join(' · ');
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
