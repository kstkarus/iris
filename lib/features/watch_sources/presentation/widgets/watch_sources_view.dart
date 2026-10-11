import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_state.dart';
import 'package:iris/features/watch_sources/presentation/models/watch_sources_sort_option.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/torrent/torrent_key.dart';
import 'package:iris/shared/widgets/adaptive/show_adaptive_sheet.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/option_toggle.dart';
import 'package:iris/shared/widgets/search_field.dart';
import 'package:iris/shared/widgets/search_toolbar.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// A title's releases. While they load, the page is pixel noise in the
/// shape of the table; the releases develop out of it when they arrive.
class WatchSourcesView extends StatelessWidget {
  const WatchSourcesView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WatchSourcesCubit, WatchSourcesState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context);
        return switch (state) {
          // One skeleton in both states, so the switch develops the page.
          WatchSourcesInitial() || WatchSourcesLoading() => AppSkeleton(
            enabled: true,
            semanticLabel: l10n.watchSourcesLoading,
            child: _LoadedState(state: _standInState),
          ),
          WatchSourcesLoaded() => AppSkeleton(
            enabled: false,
            child: _LoadedState(state: state),
          ),
          WatchSourcesEmpty() => MessageView(message: l10n.watchSourcesEmpty),
          WatchSourcesFailure() => MessageView(
            message: l10n.watchSourcesLoadError,
            action: FilledButton(
              onPressed: () => context.read<WatchSourcesCubit>().loadSources(),
              child: Text(l10n.commonRetry),
            ),
          ),
        };
      },
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchControls(
              initialQuery: state.searchQuery,
              isWide: constraints.maxWidth >= WindowSizeClass.mediumMinWidth,
              sorted: state.sortOption != WatchSourcesSortOption.seedersDesc,
              onSort: () => _openSortSheet(context),
            ),
            const SizedBox(height: 24),
            Expanded(
              // A new order replaces the whole list in place, so it
              // dissolves in; filtering as one types just updates it.
              child: DitherSwitcher(
                expand: true,
                child: KeyedSubtree(
                  key: ValueKey(state.sortOption),
                  child: items.isEmpty
                      ? MessageView(
                          message: AppLocalizations.of(
                            context,
                          ).watchSourcesSearchEmpty,
                        )
                      : _SourcesTable(
                          items: items,
                          watchedKeys: watchedKeys,
                          tabular:
                              constraints.maxWidth >=
                              WindowSizeClass.expandedMinWidth,
                        ),
                ),
              ),
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
    required this.sorted,
    required this.onSort,
  });

  final String initialQuery;
  final bool isWide;
  final bool sorted;
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
      actionIcon: PixelGlyph.sort,
      actionLabel: l10n.watchSourcesSortButton,
      actionActive: widget.sorted,
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
            for (final option in WatchSourcesSortOption.values)
              OptionToggle(
                label: _formatSortLabel(l10n, option),
                selected: option == _selectedOption,
                exclusive: true,
                onChanged: (_) => setState(() => _selectedOption = option),
              ),
            const SizedBox(height: 24),
            Align(
              alignment: AlignmentDirectional.centerEnd,
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

/// Stand-in releases: the noise takes the shape of a typical table, with
/// names of different lengths.
final _standInState = WatchSourcesLoaded(
  allItems: _standInItems,
  visibleItems: _standInItems,
  searchQuery: '',
  sortOption: WatchSourcesSortOption.seedersDesc,
);
final _standInItems = [
  for (final (index, title) in const [
    '[Group] Anime Title - 01-12 (1080p) [Batch]',
    '[Another Group] Anime Title (BD 1080p HEVC)',
    'Anime Title TV (WEB-DL 720p)',
    '[Group] Anime Title - 12 (1080p)',
    '[Raws] Anime Title (BD 1920x1080 x264 FLAC) [Batch]',
    'Anime Title (2020) [Dual Audio]',
    '[Group] Anime Title - 11 (720p)',
    '[Studio] Anime Title Complete Series',
  ].indexed)
    WatchSourceItem(
      title: title,
      magnet: 'magnet:?xt=urn:btih:standin$index',
      size: '1.4 GB',
      time: '2020-01-01',
      seeders: 120,
      downloads: 2400,
    ),
];

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

/// Column widths of the wide table, gaps included; the release name takes
/// the rest.
abstract final class _Columns {
  static const size = 112.0;
  static const seeders = 80.0;
  static const downloads = 104.0;
  static const date = 120.0;
  static const action = 52.0;
}

/// Releases are text, so they read best as rows: tapping one streams it,
/// the trailing button downloads it. Wide windows line the numbers up in
/// columns under a header.
class _SourcesTable extends StatelessWidget {
  const _SourcesTable({
    required this.items,
    required this.watchedKeys,
    required this.tabular,
  });

  final List<WatchSourceItem> items;
  final Set<String> watchedKeys;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WatchSourcesCubit>();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length + (tabular ? 1 : 0),
      itemBuilder: (context, index) {
        if (tabular && index == 0) return const _TableHeader();
        final item = items[index - (tabular ? 1 : 0)];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SegmentedRule(),
            _WatchSourceRow(
              item: item,
              tabular: tabular,
              watched: watchedKeys.contains(torrentKeyFromMagnet(item.magnet)),
              animeId: cubit.animeId,
              animeTitle: cubit.animeTitle,
            ),
          ],
        );
      },
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget cell(String text, double width) => SizedBox(
      width: width,
      child: Text(text.toUpperCase(), textAlign: TextAlign.end, style: style),
    );
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(left: 12, bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.watchSourcesColumnRelease.toUpperCase(),
                style: style,
              ),
            ),
            cell(l10n.watchSourcesColumnSize, _Columns.size),
            cell(l10n.watchSourcesColumnSeeders, _Columns.seeders),
            cell(l10n.watchSourcesColumnDownloads, _Columns.downloads),
            cell(l10n.watchSourcesColumnDate, _Columns.date),
            const SizedBox(width: _Columns.action),
          ],
        ),
      ),
    );
  }
}

class _WatchSourceRow extends StatelessWidget {
  const _WatchSourceRow({
    required this.item,
    required this.tabular,
    required this.watched,
    required this.animeId,
    required this.animeTitle,
  });

  final WatchSourceItem item;
  final bool tabular;

  /// The user streamed this release before.
  final bool watched;
  final String animeId;
  final String animeTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final numbers = NumberFormat.decimalPattern(l10n.localeName);
    final published = DateTime.tryParse(item.time);
    // Columns line dates up digit for digit; prose reads the month name.
    final date = published == null
        ? item.time
        : (tabular
                  ? DateFormat.yMd(l10n.localeName)
                  : DateFormat.yMMMd(l10n.localeName))
              .format(published);
    final cellStyle = theme.textTheme.bodyMedium;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        if (watched || !tabular) ...[
          const SizedBox(height: 4),
          _SourceFacts(
            watched: watched,
            facts: tabular
                ? null
                : [
                    if (item.size.isNotEmpty) item.size,
                    l10n.watchSourceSeeders(
                      numbers.format(item.seeders),
                      item.seeders,
                    ),
                    l10n.watchSourceDownloads(
                      numbers.format(item.downloads),
                      item.downloads,
                    ),
                    if (date.isNotEmpty) date,
                  ].join(' · '),
          ),
        ],
      ],
    );

    Widget cell(String text, double width) => SizedBox(
      width: width,
      child: Text(text, textAlign: TextAlign.end, style: cellStyle),
    );

    return Material(
      // Ink paints on the nearest Material: this one scrolls with the row,
      // so the list's edge clips the highlight.
      type: MaterialType.transparency,
      child: InkWell(
        key: const Key('watch_source_watch_button'),
        onTap: () => _openStreaming(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
          child: Row(
            children: [
              Expanded(child: title),
              if (tabular) ...[
                cell(item.size, _Columns.size),
                cell(numbers.format(item.seeders), _Columns.seeders),
                cell(numbers.format(item.downloads), _Columns.downloads),
                cell(date, _Columns.date),
                const SizedBox(width: 4),
              ] else
                const SizedBox(width: 8),
              IconButton(
                key: const Key('watch_source_download_button'),
                tooltip: l10n.downloadsOpenButton,
                icon: const PixelIcon(PixelGlyph.download, size: 18),
                onPressed: () => _openDownload(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStreaming(BuildContext context) {
    context.pushNamed(
      'torrent-stream-files',
      extra: AnimePlayerSourceArgs(
        animeId: animeId,
        animeTitle: animeTitle,
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
        animeTitle: animeTitle,
        sourceTitle: item.title,
        magnet: item.magnet,
      ),
    );
  }
}

/// The "watched" mark and, in the narrow layout, the numbers the wide
/// table shows in columns.
class _SourceFacts extends StatelessWidget {
  const _SourceFacts({required this.watched, required this.facts});

  final bool watched;
  final String? facts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final facts = this.facts;
    return Text.rich(
      key: watched ? const Key('watch_source_used_badge') : null,
      TextSpan(
        children: [
          if (watched) ...[
            TextSpan(
              text: l10n.watchSourceUsedBadge,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            if (facts != null) const TextSpan(text: ' · '),
          ],
          ?(facts == null ? null : TextSpan(text: facts)),
        ],
      ),
      style: theme.textTheme.bodySmall,
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
