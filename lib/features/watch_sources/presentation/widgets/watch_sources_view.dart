import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:iris/entities/anime/domain/anime_titles.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_state.dart';
import 'package:iris/features/watch_sources/presentation/models/watch_sources_sort_option.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/haptics/app_haptics.dart';
import 'package:iris/shared/torrent/torrent_key.dart';
import 'package:iris/shared/utils/watched_first.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/show_adaptive_sheet.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/app_skeleton.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_scroll_edge.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/option_toggle.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/search_field.dart';
import 'package:iris/shared/widgets/search_toolbar.dart';
import 'package:iris/shared/widgets/source_facts_line.dart';
import 'package:iris/shared/widgets/status_views.dart';
import 'package:iris/shared/widgets/tap_row.dart';

/// A title's releases. While they load, the page is pixel noise in the
/// shape of the table; the releases develop out of it when they arrive.
/// When none are found it offers to add a torrent of the user's own.
class WatchSourcesView extends StatelessWidget {
  const WatchSourcesView({
    required this.onAddTorrent,
    this.posterUrl = '',
    this.downloadedCounts = const {},
    this.horizontalPadding = 0,
    this.desktopSplit = false,
    this.onOpenSource,
    super.key,
  });

  static const addTorrentKey = Key('watch_sources_add_own_torrent');

  final VoidCallback onAddTorrent;
  final String posterUrl;
  final Map<String, int> downloadedCounts;

  /// Horizontal gutter inside rows so tap/hover fills can bleed edge-to-edge
  /// while text and dividers align with the page frame.
  final double horizontalPadding;

  /// True inside the desktop split layout where the right column is capped
  /// beside the poster rail.
  final bool desktopSplit;

  /// Optional inline handler (used by desktop anime details to stay in the
  /// same dossier frame instead of pushing a separate route).
  final ValueChanged<AnimePlayerSourceArgs>? onOpenSource;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WatchSourcesCubit, WatchSourcesState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context);
        final (Object key, Widget view) = switch (state) {
          // One skeleton in both states, so the switch develops the page.
          WatchSourcesInitial() || WatchSourcesLoading() => (
            'searching',
            AppSkeleton(
              enabled: true,
              semanticLabel: l10n.watchSourcesLoading,
              child: _LoadedState(
                state: _standInState,
                posterUrl: posterUrl,
                downloadedCounts: const {},
                horizontalPadding: horizontalPadding,
                desktopSplit: desktopSplit,
              ),
            ),
          ),
          WatchSourcesLoaded() => (
            'loaded',
            AppSkeleton(
              enabled: false,
              child: _LoadedState(
                state: state,
                posterUrl: posterUrl,
                downloadedCounts: downloadedCounts,
                horizontalPadding: horizontalPadding,
                desktopSplit: desktopSplit,
                onOpenSource: onOpenSource,
              ),
            ),
          ),
          WatchSourcesEmpty() => (
            'empty',
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: MessageView(
                message: l10n.watchSourcesEmpty,
                action: OutlinedButton(
                  key: addTorrentKey,
                  onPressed: onAddTorrent,
                  child: Text(l10n.watchSourcesAddOwnTorrent),
                ),
              ),
            ),
          ),
          WatchSourcesFailure() => (
            'failure',
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: RetryView(
                message: l10n.watchSourcesLoadError,
                onRetry: () => context.read<WatchSourcesCubit>().loadSources(),
              ),
            ),
          ),
        };
        return DitherSwitcher(
          expand: true,
          child: KeyedSubtree(key: ValueKey(key), child: view),
        );
      },
    );
  }
}

class _LoadedState extends StatelessWidget {
  const _LoadedState({
    required this.state,
    required this.posterUrl,
    required this.downloadedCounts,
    required this.horizontalPadding,
    required this.desktopSplit,
    this.onOpenSource,
  });

  static const _splitTabularMinWidth = 680.0;
  static const _downloadsColumnMinWidth = 780.0;

  final WatchSourcesLoaded state;
  final String posterUrl;
  final Map<String, int> downloadedCounts;
  final double horizontalPadding;
  final bool desktopSplit;
  final ValueChanged<AnimePlayerSourceArgs>? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final watchedKeys = {
      for (final progress in context.watchWatchProgress()) progress.torrentKey,
    };
    final items = watchedKeys.isEmpty
        ? state.visibleItems
        : watchedFirst(
            state.visibleItems,
            (item) => watchedKeys.contains(torrentKeyFromMagnet(item.magnet)),
          );
    final largeText = DetailLayout.isLargeText(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabular =
            !largeText &&
            constraints.maxWidth >=
                (desktopSplit
                    ? _splitTabularMinWidth
                    : WindowSizeClass.expandedMinWidth);
        final showDownloads = constraints.maxWidth >= _downloadsColumnMinWidth;
        final controlsPadding = desktopSplit ? 0.0 : horizontalPadding;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                controlsPadding,
                4,
                controlsPadding,
                0,
              ),
              child: _SearchControls(
                initialQuery: state.searchQuery,
                isWide: constraints.maxWidth >= WindowSizeClass.mediumMinWidth,
                showSortAction: !tabular,
                sorted: state.sortOption != WatchSourcesSortOption.seedersDesc,
                onSort: () => _openSortSheet(context),
              ),
            ),
            SizedBox(height: tabular ? 16 : 12),
            // Keep focus on the column button while the rows change order.
            if (tabular && items.isNotEmpty)
              _TableHeader(
                sortOption: state.sortOption,
                onSort: context.read<WatchSourcesCubit>().updateSortOption,
                horizontalPadding: horizontalPadding,
                showDownloads: showDownloads,
              ),
            Expanded(
              key: const ValueKey('watch_sources_body'),
              // A new order or empty-search swap dissolves in briskly;
              // filtering within non-empty results updates immediately.
              child: DitherSwitcher(
                expand: true,
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey((state.sortOption, items.isEmpty)),
                  child: items.isEmpty
                      ? Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          child: MessageView(
                            message: AppLocalizations.of(
                              context,
                            ).watchSourcesSearchEmpty,
                          ),
                        )
                      : tabular
                      ? _SourcesTable(
                          items: items,
                          watchedKeys: watchedKeys,
                          posterUrl: posterUrl,
                          downloadedCounts: downloadedCounts,
                          tabular: tabular,
                          showDownloads: showDownloads,
                          horizontalPadding: horizontalPadding,
                          desktopSplit: desktopSplit,
                          onOpenSource: onOpenSource,
                        )
                      : DitherScrollEdge(
                          child: _SourcesTable(
                            items: items,
                            watchedKeys: watchedKeys,
                            posterUrl: posterUrl,
                            downloadedCounts: downloadedCounts,
                            tabular: tabular,
                            showDownloads: showDownloads,
                            horizontalPadding: horizontalPadding,
                            desktopSplit: desktopSplit,
                            onOpenSource: onOpenSource,
                          ),
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
    required this.showSortAction,
    required this.sorted,
    required this.onSort,
  });

  final String initialQuery;
  final bool isWide;
  final bool showSortAction;
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
    final field = SearchField(
      controller: _controller,
      hintText: l10n.watchSourcesSearchHint,
      onChanged: context.read<WatchSourcesCubit>().updateSearchQuery,
    );
    if (!widget.showSortAction) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AdaptiveContentWidth.form,
          ),
          child: field,
        ),
      );
    }
    return SearchToolbar(
      searchField: field,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rule = DetailLayout.ruleColor(scheme);
    final applyButton = FilledButton(
      onPressed: () {
        widget.onApply(_selectedOption);
        Navigator.of(context).pop();
      },
      child: Text(l10n.watchSourcesSortApplyButton),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.watchSourcesSortSheetTitle,
              style: theme.textTheme.titleLarge?.copyWith(wordSpacing: -3.6),
            ),
            const SizedBox(height: 16),
            Material(
              color: scheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(side: BorderSide(color: rule)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, option)
                      in WatchSourcesSortOption.values.indexed) ...[
                    if (index > 0)
                      Divider(height: 1, thickness: 1, color: rule),
                    OptionToggle(
                      label: _formatSortLabel(l10n, option),
                      selected: option == _selectedOption,
                      exclusive: true,
                      onChanged: (_) {
                        if (option == _selectedOption) return;
                        AppHaptics.selection();
                        setState(() => _selectedOption = option);
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (WindowSizeClass.of(context).isCompact)
              applyButton
            else
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: applyButton,
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

/// Column widths of the wide table, gaps included; the release name takes
/// the rest.
abstract final class _Columns {
  static const size = 96.0;
  static const seeders = 72.0;
  static const downloads = 92.0;
  static const date = 104.0;
}

/// Each row opens the release. Wide windows line the tracker numbers up
/// in columns under an open editorial header.
class _SourcesTable extends StatelessWidget {
  const _SourcesTable({
    required this.items,
    required this.watchedKeys,
    required this.posterUrl,
    required this.downloadedCounts,
    required this.tabular,
    required this.showDownloads,
    required this.horizontalPadding,
    required this.desktopSplit,
    required this.onOpenSource,
  });

  final List<WatchSourceItem> items;
  final Set<String> watchedKeys;
  final String posterUrl;
  final Map<String, int> downloadedCounts;
  final bool tabular;
  final bool showDownloads;
  final double horizontalPadding;
  final bool desktopSplit;
  final ValueChanged<AnimePlayerSourceArgs>? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WatchSourcesCubit>();
    final scheme = Theme.of(context).colorScheme;
    final dividerColor = DetailLayout.ruleColor(scheme).withValues(alpha: 0.45);
    final dividerIndent = desktopSplit ? 0.0 : horizontalPadding;

    final list = ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final key = torrentKeyFromMagnet(item.magnet);
        final watched = watchedKeys.contains(key);
        final row = DecoratedBox(
          decoration: BoxDecoration(
            border: tabular
                ? Border(
                    left: BorderSide(
                      width: 2,
                      color: watched ? scheme.onSurface : Colors.transparent,
                    ),
                  )
                : null,
          ),
          child: _WatchSourceRow(
            item: item,
            tabular: tabular,
            showDownloads: showDownloads,
            horizontalPadding: horizontalPadding,
            watched: watched,
            downloadedCount: downloadedCounts[key] ?? 0,
            animeId: cubit.animeId,
            animeTitles: cubit.animeTitles,
            posterUrl: posterUrl,
            onOpenSource: onOpenSource,
          ),
        );
        if (index == items.length - 1) return row;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row,
            Divider(
              height: 1,
              thickness: 1,
              indent: dividerIndent,
              endIndent: dividerIndent,
              color: dividerColor,
            ),
          ],
        );
      },
    );
    if (!tabular) return list;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              FocusScope.of(context).nextFocus(),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              FocusScope.of(context).previousFocus(),
        },
        child: list,
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.sortOption,
    required this.onSort,
    required this.horizontalPadding,
    required this.showDownloads,
  });

  final WatchSourcesSortOption sortOption;
  final ValueChanged<WatchSourcesSortOption> onSort;
  final double horizontalPadding;
  final bool showDownloads;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelMedium?.copyWith(
      fontFamily: DetailLayout.sansFont,
      fontWeight: FontWeight.w500,
    );
    Widget cell(String label, WatchSourcesSortOption option, {double? width}) {
      final leading = width == null;
      final selected = sortOption == option;
      return SizedBox(
        width: width,
        child: Semantics(
          button: true,
          selected: selected,
          child: InkWell(
            onTap: () {
              if (!selected) AppHaptics.selection();
              onSort(option);
            },
            mouseCursor: SystemMouseCursors.click,
            hoverColor: scheme.onSurface.withValues(alpha: 0.08),
            focusColor: scheme.onSurface.withValues(alpha: 0.16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: Align(
                      alignment: leading
                          ? AlignmentDirectional.centerStart
                          : AlignmentDirectional.centerEnd,
                      child: Text(
                        label,
                        textAlign: leading ? TextAlign.start : TextAlign.end,
                        style: style?.copyWith(
                          color: selected
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    PositionedDirectional(
                      start: leading ? 0 : null,
                      end: leading ? null : 0,
                      bottom: 3,
                      child: RotatedBox(
                        quarterTurns: leading ? 2 : 0,
                        child: PixelIcon(
                          PixelGlyph.expand,
                          size: 8,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: DetailLayout.ruleColor(scheme)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding + 2,
          0,
          horizontalPadding,
          0,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: cell(
                  l10n.watchSourcesColumnRelease,
                  WatchSourcesSortOption.titleAsc,
                ),
              ),
              cell(
                l10n.watchSourcesColumnSize,
                WatchSourcesSortOption.sizeDesc,
                width: _Columns.size,
              ),
              cell(
                l10n.watchSourcesColumnSeeders,
                WatchSourcesSortOption.seedersDesc,
                width: _Columns.seeders,
              ),
              if (showDownloads)
                cell(
                  l10n.watchSourcesColumnDownloads,
                  WatchSourcesSortOption.downloadsDesc,
                  width: _Columns.downloads,
                ),
              cell(
                l10n.watchSourcesColumnDate,
                WatchSourcesSortOption.publishedAtDesc,
                width: _Columns.date,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchSourceRow extends StatelessWidget {
  const _WatchSourceRow({
    required this.item,
    required this.tabular,
    required this.showDownloads,
    required this.horizontalPadding,
    required this.watched,
    required this.downloadedCount,
    required this.animeId,
    required this.animeTitles,
    required this.posterUrl,
    required this.onOpenSource,
  });

  final WatchSourceItem item;
  final bool tabular;
  final bool showDownloads;
  final double horizontalPadding;

  /// The user streamed this release before.
  final bool watched;
  final int downloadedCount;
  final String animeId;
  final AnimeTitles animeTitles;
  final String posterUrl;
  final ValueChanged<AnimePlayerSourceArgs>? onOpenSource;

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
    final cellStyle = DetailLayout.monoTelemetryStyle(
      theme.textTheme.bodySmall,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final facts = [
      if (downloadedCount > 0)
        _unbreakable(l10n.playerSourceDownloadedCount(downloadedCount)),
      if (!tabular) ...[
        if (item.size.isNotEmpty) _unbreakable(item.size),
        _unbreakable(
          l10n.watchSourceSeeders(numbers.format(item.seeders), item.seeders),
        ),
        _unbreakable(
          l10n.watchSourceDownloads(
            numbers.format(item.downloads),
            item.downloads,
          ),
        ),
        if (date.isNotEmpty) _unbreakable(date),
      ],
    ];

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          maxLines: tabular ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: DetailLayout.sansFont,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.32,
          ),
        ),
        if (watched || facts.isNotEmpty) ...[
          const SizedBox(height: 5),
          SourceFactsLine(
            key: watched ? const Key('watch_source_used_badge') : null,
            watched: watched,
            cleanLineWrap: true,
            facts: facts.isEmpty ? null : facts.join(' · '),
          ),
        ],
      ],
    );

    Widget cell(String text, double width, {Color? color}) => SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.end,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: color == null ? cellStyle : cellStyle?.copyWith(color: color),
      ),
    );

    return TapRow(
      inkKey: const Key('watch_source_watch_button'),
      onTap: () => _open(context),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: tabular ? 13 : 14,
        ),
        child: Row(
          children: [
            Expanded(child: title),
            if (tabular) ...[
              cell(item.size, _Columns.size),
              cell(
                numbers.format(item.seeders),
                _Columns.seeders,
                color: theme.colorScheme.onSurface,
              ),
              if (showDownloads)
                cell(numbers.format(item.downloads), _Columns.downloads),
              cell(date, _Columns.date),
            ],
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final sourceArgs = AnimePlayerSourceArgs(
      animeId: animeId,
      animeTitles: animeTitles,
      sourceTitle: item.title,
      magnet: item.magnet,
      posterUrl: posterUrl,
    );
    final handler = onOpenSource;
    if (handler != null) {
      handler(sourceArgs);
      return;
    }
    context.pushNamed('torrent-stream-files', extra: sourceArgs);
  }
}

String _unbreakable(String value) => value.replaceAll(' ', '\u00A0');

String _formatSortLabel(AppLocalizations l10n, WatchSourcesSortOption option) {
  switch (option) {
    case WatchSourcesSortOption.seedersDesc:
      return l10n.watchSourcesSortSeeders;
    case WatchSourcesSortOption.publishedAtDesc:
      return l10n.watchSourcesSortPublishedAt;
    case WatchSourcesSortOption.downloadsDesc:
      return l10n.watchSourcesSortDownloads;
    case WatchSourcesSortOption.sizeDesc:
      return l10n.watchSourcesSortSize;
    case WatchSourcesSortOption.titleAsc:
      return l10n.watchSourcesSortTitle;
  }
}
