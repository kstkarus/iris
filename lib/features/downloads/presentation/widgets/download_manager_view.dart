import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/shared/widgets/adaptive/show_app_dialog.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/online/online_source_link.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_state.dart';
import 'package:iris/features/downloads/presentation/widgets/download_status_label.dart';
import 'package:iris/features/downloads/presentation/widgets/download_labels.dart';
import 'package:iris/features/downloads/presentation/widgets/download_deletion_dialog.dart';
import 'package:iris/features/downloads/presentation/widgets/download_files.dart';
import 'package:iris/features/downloads/presentation/widgets/download_library_header.dart';
import 'package:iris/features/downloads/presentation/widgets/download_selection_footer.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/desktop_platform.dart';
import 'package:iris/shared/utils/episode_number.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/features/downloads/presentation/widgets/download_title_widgets.dart';
import 'package:iris/shared/widgets/focusable_list_row.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/row_menu_button.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/status_views.dart';
import 'package:iris/shared/widgets/dither_list.dart';

const _episodeRemovalDuration = Duration(milliseconds: 320);

class DownloadManagerView extends StatefulWidget {
  const DownloadManagerView({
    required this.onWatch,
    required this.onBrowseCatalog,
    required this.onOpenTitle,
    this.onOpenAnime,
    this.onDownloadMore,
    this.titleKey,
    this.onOpenQueue,
    this.onTitleDeleted,
    super.key,
  });

  final ValueChanged<DownloadItem> onWatch;
  final ValueChanged<DownloadTitle> onOpenTitle;
  final ValueChanged<DownloadTitle>? onOpenAnime;
  final ValueChanged<DownloadItem>? onDownloadMore;
  final String? titleKey;
  final VoidCallback? onOpenQueue;
  final FutureOr<bool> Function()? onTitleDeleted;

  /// Where an empty list leads: episodes are downloaded from a title's
  /// sources.
  final VoidCallback onBrowseCatalog;

  @override
  State<DownloadManagerView> createState() => _DownloadManagerViewState();
}

class _DownloadManagerViewState extends State<DownloadManagerView> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadManagerCubit, DownloadManagerState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context);
        final Widget? placeholder = state.downloads.isEmpty && state.isLoading
            ? LoadingView(semanticsLabel: l10n.downloadsLoading)
            : state.downloads.isEmpty && state.hasError
            ? RetryView(
                message: l10n.downloadManagerUnableToLoad,
                onRetry: context.read<DownloadManagerCubit>().load,
              )
            : null;
        final titles = downloadTitles(state.downloads);
        if (widget.titleKey case final key?) {
          if (placeholder != null) return placeholder;
          final title = titles.where((title) => title.key == key).firstOrNull;
          return _Episodes(
            key: ValueKey(key),
            titleKey: key,
            onWatch: widget.onWatch,
            title: title,
            onOpenAnime: widget.onOpenAnime,
            onDownloadMore: widget.onDownloadMore,
            onTitleDeleted: widget.onTitleDeleted,
          );
        }
        final library =
            placeholder ??
            (isDesktopPlatform
                ? _DesktopLibrary(
                    titles: titles,
                    onWatch: widget.onWatch,
                    onOpenAnime: widget.onOpenAnime,
                    onDownloadMore: widget.onDownloadMore,
                    onBrowseCatalog: widget.onBrowseCatalog,
                  )
                : titles.isEmpty
                ? _EmptyLibrary(onBrowseCatalog: widget.onBrowseCatalog)
                : DownloadLibraryGallery(
                    titles: titles,
                    onOpenTitle: widget.onOpenTitle,
                  ));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DownloadLibraryHeader(
              queueCount: state.queue.length,
              showQueue: state.downloads.any(
                (item) => item.status != DownloadStatus.completed,
              ),
              onQueue: widget.onOpenQueue,
              onFiles: () async {
                final title = await showDownloadFiles(context);
                if (title != null && context.mounted) widget.onOpenTitle(title);
              },
            ),
            const SizedBox(height: 16),
            Expanded(child: library),
          ],
        );
      },
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onBrowseCatalog});
  final VoidCallback onBrowseCatalog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: const Alignment(0, -0.2),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 392),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PixelIcon(
                            PixelGlyph.download,
                            size: 42,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 24),
                          Semantics(
                            header: true,
                            child: Text(
                              l10n.downloadsEmptyTitle,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.downloadsEmpty,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            key: const Key('downloads_browse_catalog'),
                            onPressed: onBrowseCatalog,
                            child: Text(l10n.commonBrowseCatalog),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopLibrary extends StatefulWidget {
  const _DesktopLibrary({
    required this.titles,
    required this.onWatch,
    required this.onBrowseCatalog,
    this.onOpenAnime,
    this.onDownloadMore,
  });
  final List<DownloadTitle> titles;
  final ValueChanged<DownloadItem> onWatch;
  final VoidCallback onBrowseCatalog;
  final ValueChanged<DownloadTitle>? onOpenAnime;
  final ValueChanged<DownloadItem>? onDownloadMore;

  @override
  State<_DesktopLibrary> createState() => _DesktopLibraryState();
}

class _DesktopLibraryState extends State<_DesktopLibrary> {
  late String? _selectedKey = widget.titles.firstOrNull?.key;

  @override
  void didUpdateWidget(covariant _DesktopLibrary oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedKey ??= widget.titles.firstOrNull?.key;
  }

  @override
  Widget build(BuildContext context) {
    final selectedKey = _selectedKey;
    if (selectedKey == null) {
      return _EmptyLibrary(onBrowseCatalog: widget.onBrowseCatalog);
    }
    final selected = widget.titles
        .where((title) => title.key == selectedKey)
        .firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 800;
        Widget option(DownloadTitle title) => DownloadPosterOption(
          title: title,
          selected: title.key == selectedKey,
          onTap: () => setState(() => _selectedKey = title.key),
        );
        final details = DitherSwitcher(
          expand: true,
          child: _Episodes(
            key: ValueKey('download_episodes_$selectedKey'),
            titleKey: selectedKey,
            title: selected,
            onWatch: widget.onWatch,
            onOpenAnime: widget.onOpenAnime,
            onDownloadMore: widget.onDownloadMore,
            desktop: true,
            onTitleDeleted: () {
              if (_selectedKey == selectedKey &&
                  !widget.titles.any((title) => title.key == selectedKey)) {
                setState(() => _selectedKey = widget.titles.firstOrNull?.key);
              }
              return true;
            },
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (narrow) ...[
              SizedBox(
                height: 124,
                child: ListView.separated(
                  key: const Key('download_poster_list'),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.titles.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => option(widget.titles[index]),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(child: details),
            ] else
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: DitherList<DownloadTitle>(
                        key: const Key('download_poster_list'),
                        padding: const EdgeInsets.only(bottom: 32),
                        items: widget.titles,
                        keyOf: (title) => title.key,
                        itemBuilder: (context, title) => Align(
                          alignment: Alignment.topCenter,
                          child: option(title),
                        ),
                        rowSpacing: 12,
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(child: details),
                  ],
                ),
              ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

class _DownloadsMenu extends StatefulWidget {
  const _DownloadsMenu({
    this.title,
    this.onOpenAnime,
    this.onDownloadMore,
    this.onSelect,
  });
  final DownloadTitle? title;
  final ValueChanged<DownloadTitle>? onOpenAnime;
  final VoidCallback? onDownloadMore;
  final VoidCallback? onSelect;

  @override
  State<_DownloadsMenu> createState() => _DownloadsMenuState();
}

class _DownloadsMenuState extends State<_DownloadsMenu> {
  final _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = widget.title;
    final canOpenAnime =
        title != null &&
        widget.onOpenAnime != null &&
        title.items.any((item) => item.animeId.isNotEmpty);
    if (title != null &&
        !canOpenAnime &&
        widget.onDownloadMore == null &&
        title.items.length == 1 &&
        widget.onSelect == null) {
      return const SizedBox.shrink();
    }
    return RowMenuButton(
      key: Key(title == null ? 'download_library_menu' : 'download_title_menu'),
      controller: _controller,
      tooltip: l10n.commonMoreActions,
      menuChildren: [
        if (widget.onSelect case final select?)
          MenuItemButton(
            key: const Key('download_title_select'),
            onPressed: select,
            child: Text(l10n.downloadSelect),
          ),
        if (widget.onDownloadMore case final downloadMore?)
          MenuItemButton(
            key: const Key('download_title_download_more'),
            onPressed: downloadMore,
            child: Text(l10n.downloadMore),
          ),
        if (canOpenAnime)
          MenuItemButton(
            key: const Key('download_title_open_anime'),
            onPressed: () => widget.onOpenAnime?.call(title),
            child: Text(l10n.downloadOpenAnime),
          ),
        if (title != null && title.items.length > 1)
          MenuItemButton(
            key: const Key('download_title_delete_all'),
            onPressed: () async {
              final items = context
                  .read<DownloadManagerCubit>()
                  .state
                  .downloads
                  .where((item) => downloadTitleKey(item) == title.key)
                  .toList();
              await confirmDownloadDeletion(
                context,
                items,
                title.name,
                all: true,
              );
            },
            child: Text(asksForMore(l10n.downloadDeleteAll)),
          ),
      ],
    );
  }
}

Future<void> _showDownloadStatus(
  BuildContext context, {
  required String itemId,
}) async {
  final cubit = context.read<DownloadManagerCubit>();
  await showAppDialog<void>(
    context: context,
    builder: (context) => BlocProvider<DownloadManagerCubit>.value(
      value: cubit,
      child: _DownloadStatusDialog(itemId: itemId),
    ),
  );
}

class _DownloadStatusDialog extends StatelessWidget {
  const _DownloadStatusDialog({required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const Key('download_status_dialog'),
      scrollable: true,
      title: Text(l10n.downloadStatusDetails),
      content: SizedBox(
        width: 560,
        child: BlocBuilder<DownloadManagerCubit, DownloadManagerState>(
          builder: (context, state) {
            final item = state.downloads
                .where((item) => item.id == itemId)
                .firstOrNull;
            if (item == null) return Text(l10n.downloadTitleEmpty);
            final number = episodeNumberFromFileName(item.fileName);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (number != null) ...[
                  Text(
                    l10n.downloadEpisodeLabel(
                      number.toString().padLeft(2, '0'),
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  downloadStatusLabel(l10n, item.status),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  _facts(l10n, item),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (item.failure case final failure?) ...[
                  const SizedBox(height: 4),
                  Text(
                    downloadFailureMessage(l10n, failure),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonTooltip),
        ),
      ],
    );
  }
}

class _Episodes extends StatefulWidget {
  const _Episodes({
    required this.titleKey,
    required this.onWatch,
    this.title,
    this.desktop = false,
    this.onOpenAnime,
    this.onDownloadMore,
    this.onTitleDeleted,
    super.key,
  });

  final String titleKey;
  final DownloadTitle? title;
  List<DownloadItem> get downloads => title?.items ?? const [];
  final ValueChanged<DownloadItem> onWatch;
  final bool desktop;
  final ValueChanged<DownloadTitle>? onOpenAnime;
  final ValueChanged<DownloadItem>? onDownloadMore;
  final FutureOr<bool> Function()? onTitleDeleted;

  @override
  State<_Episodes> createState() => _EpisodesState();
}

class _EpisodesState extends State<_Episodes> {
  final _selected = <String>{};
  final _focus = FocusNode();
  late DownloadTitle? _lastTitle = widget.title;
  String? _anchor;
  bool _selecting = false;
  bool _busy = false;
  int _failureCount = 0;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _Episodes oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selected.retainAll(widget.downloads.map((item) => item.id).toSet());
    if (widget.title case final title?) _lastTitle = title;
  }

  Future<void> _episodesEmptied() async {
    if (widget.title != null || (_lastTitle == null && !widget.desktop)) return;
    if (await widget.onTitleDeleted?.call() == true ||
        !mounted ||
        widget.title != null) {
      return;
    }
    setState(() {
      _lastTitle = null;
      _selecting = false;
      _failureCount = 0;
    });
  }

  void _cancelSelection() {
    if (_busy) return;
    setState(() {
      _selecting = false;
      _selected.clear();
      _anchor = null;
      _failureCount = 0;
    });
  }

  void _toggle(String id) {
    if (_busy) return;
    final ids = _releases(
      widget.downloads,
    ).expand((release) => release).map((item) => item.id).toList();
    final anchor = ids.indexOf(_anchor ?? '');
    final end = ids.indexOf(id);
    if (end < 0) return;
    setState(() {
      _failureCount = 0;
      if (HardwareKeyboard.instance.isShiftPressed && anchor >= 0) {
        _selected.addAll(
          ids.sublist(math.min(anchor, end), math.max(anchor, end) + 1),
        );
      } else if (!_selected.remove(id)) {
        _selected.add(id);
      }
      _anchor = id;
    });
  }

  void _toggleGroup(Iterable<DownloadItem> items) {
    if (_busy) return;
    final ids = items.map((item) => item.id).toSet();
    setState(() {
      _failureCount = 0;
      if (ids.every(_selected.contains)) {
        _selected.removeAll(ids);
      } else {
        _selected.addAll(ids);
      }
      _anchor = null;
    });
  }

  Future<void> _deleteSelected() async {
    if (_busy || _selected.isEmpty) return;
    final items = widget.downloads
        .where((item) => _selected.contains(item.id))
        .toList();
    final title = widget.title;
    if (items.isEmpty || title == null) return;
    setState(() => _busy = true);
    final failed = await confirmDownloadDeletion(
      context,
      items,
      title.name,
      selected: true,
    );
    if (!mounted) return;
    final remaining = context
        .read<DownloadManagerCubit>()
        .state
        .downloads
        .map((item) => item.id)
        .toSet();
    setState(() {
      _busy = false;
      if (failed != null) {
        _selected
          ..clear()
          ..addAll(failed.intersection(remaining));
        _failureCount = _selected.length;
        _selecting = _selected.isNotEmpty;
        _anchor = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = widget.title;
    final downloads = widget.downloads;
    final onDownloadMore = widget.onDownloadMore;
    final manager = context.watch<DownloadManagerCubit>().state;
    final releases = _releases(downloads);
    final sharedHeights = {
      for (final release in releases)
        downloadSourceKey(release.first.magnet): _sharedReleaseHeight(release),
    };
    final downloadMore = onDownloadMore != null && releases.length == 1
        ? () => onDownloadMore(releases.single.first)
        : null;
    final menu = title != null
        ? _DownloadsMenu(
            title: title,
            onOpenAnime: widget.onOpenAnime,
            onDownloadMore: downloadMore,
            onSelect: () {
              setState(() => _selecting = true);
              _focus.requestFocus();
            },
          )
        : _lastTitle != null
        ? const SizedBox(width: 48)
        : null;

    Widget episodesList({Widget? header}) => DitherList<(String, Widget)>(
      key: ValueKey('download_episodes_list_${widget.titleKey}'),
      padding: const EdgeInsets.only(bottom: 32),
      header: header,
      removalDuration: _episodeRemovalDuration,
      onEmptied: _episodesEmptied,
      footer: _lastTitle == null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Text(
                l10n.downloadTitleEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : null,
      keyOf: (row) => row.$1,
      itemBuilder: (context, row) => row.$2,
      items: [
        for (final release in releases) ...[
          (
            'release:${downloadSourceKey(release.first.magnet)}',
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _ReleaseFacts(
                      item: release.first,
                      videoHeight:
                          sharedHeights[downloadSourceKey(
                            release.first.magnet,
                          )],
                    ),
                  ),
                  if (releases.length > 1)
                    SizedBox(
                      height: 48,
                      child: DitherSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _selecting
                            ? Checkbox(
                                key: ValueKey(
                                  'download_group_select_${downloadSourceKey(release.first.magnet)}',
                                ),
                                tristate: true,
                                value:
                                    release.every(
                                      (item) => _selected.contains(item.id),
                                    )
                                    ? true
                                    : release.any(
                                        (item) => _selected.contains(item.id),
                                      )
                                    ? null
                                    : false,
                                semanticLabel: downloadSourceLabel(
                                  l10n,
                                  release.first,
                                ),
                                onChanged: _busy
                                    ? null
                                    : (_) => _toggleGroup(release),
                              )
                            : onDownloadMore != null
                            ? TextButton.icon(
                                key: ValueKey(
                                  'download_more_${downloadSourceKey(release.first.magnet)}',
                                ),
                                onPressed: () => onDownloadMore(release.first),
                                icon: const PixelIcon(
                                  PixelGlyph.download,
                                  size: 14,
                                ),
                                label: Text(l10n.downloadMore),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('no_download_more'),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          for (final item in release)
            (
              'file:${item.id}',
              Column(
                children: [
                  const SegmentedRule(),
                  _DownloadRow(
                    key: ValueKey(item.id),
                    item: item,
                    videoHeight:
                        sharedHeights[downloadSourceKey(
                              release.first.magnet,
                            )] ==
                            null
                        ? item.videoHeight
                        : null,
                    onWatch: widget.onWatch,
                    selecting: _selecting,
                    selected: _selected.contains(item.id),
                    disabled: _busy || manager.deletingIds.contains(item.id),
                    onSelect: () => _toggle(item.id),
                    onDeleteSelected: _deleteSelected,
                  ),
                ],
              ),
            ),
        ],
      ],
    );

    final allSelected =
        downloads.isNotEmpty &&
        downloads.every((item) => _selected.contains(item.id));
    final actionStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
    return PopScope(
      canPop: !_selecting || _busy || downloads.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelSelection();
      },
      child: CallbackShortcuts(
        bindings: {
          if (_selecting) ...{
            const SingleActivator(LogicalKeyboardKey.escape): _cancelSelection,
            const SingleActivator(LogicalKeyboardKey.delete): _deleteSelected,
          },
        },
        child: Focus(
          focusNode: _focus,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                key: const Key('download_delete_list'),
                child: DownloadAdaptiveTitleHeader(
                  title: _lastTitle,
                  desktop: widget.desktop,
                  menu: menu,
                  selectionActions: _selecting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: TextButton(
                                key: const Key('download_delete_cancel'),
                                style: actionStyle,
                                onPressed: _busy ? null : _cancelSelection,
                                child: Text(
                                  l10n.downloadCancelButton,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                            Flexible(
                              child: TextButton(
                                key: const Key('download_delete_all'),
                                style: actionStyle,
                                onPressed: _busy
                                    ? null
                                    : () => _toggleGroup(downloads),
                                child: Text(
                                  allSelected
                                      ? l10n.downloadDeselectAll
                                      : l10n.downloadSelectAll,
                                  maxLines: 2,
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ),
                          ],
                        )
                      : null,
                  buildList: (header) => episodesList(header: header),
                ),
              ),
              if (_selecting && _failureCount > 0)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.downloadDeleteSelectionFailed(_failureCount),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              DownloadSelectionFooter(
                visible: _selecting,
                child: FilledButton(
                  key: const Key('download_delete_selected'),
                  onPressed: _busy || _selected.isEmpty
                      ? null
                      : _deleteSelected,
                  child: Text(
                    _busy && manager.deletingIds.isNotEmpty
                        ? l10n.downloadDeleting
                        : l10n.downloadDeleteSelected(_selected.length),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReleaseFacts extends StatelessWidget {
  const _ReleaseFacts({required this.item, this.videoHeight});
  final DownloadItem item;
  final int? videoHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: item.sourceTitle,
      child: Semantics(
        header: true,
        child: Text(
          downloadSourceLabel(l10n, item, videoHeight: videoHeight),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

int? _sharedReleaseHeight(List<DownloadItem> release) {
  if (release.isEmpty) return null;
  final height = release.first.videoHeight;
  return height != null && release.every((item) => item.videoHeight == height)
      ? height
      : null;
}

List<List<DownloadItem>> _releases(List<DownloadItem> downloads) {
  final groups = <String, List<DownloadItem>>{};
  for (final item in downloads) {
    groups.putIfAbsent(downloadSourceKey(item.magnet), () => []).add(item);
  }
  return [for (final release in groups.values) release..sort(_byEpisode)];
}

/// One file. The row plays a finished file; its one button does what the
/// status calls for, and the rest (delete) is in its menu, which a long
/// press, a right click and the Delete key also reach.
class _DownloadRow extends StatefulWidget {
  const _DownloadRow({
    required this.item,
    required this.onWatch,
    this.videoHeight,
    required this.selecting,
    required this.selected,
    required this.disabled,
    required this.onSelect,
    required this.onDeleteSelected,
    super.key,
  });

  final DownloadItem item;
  final ValueChanged<DownloadItem> onWatch;
  final int? videoHeight;
  final bool selecting;
  final bool selected;
  final bool disabled;
  final VoidCallback onSelect;
  final VoidCallback onDeleteSelected;

  @override
  State<_DownloadRow> createState() => _DownloadRowState();
}

class _DownloadRowState extends State<_DownloadRow> {
  final _menu = MenuController();
  bool _menuOpen = false;

  void _setMenuOpen(bool open) {
    if (mounted) setState(() => _menuOpen = open);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DownloadManagerCubit>();
    final item = widget.item;
    final status = item.status;
    final completed = status == DownloadStatus.completed;
    final name = downloadName(l10n, item);
    final semanticName = downloadSemanticName(l10n, item);
    final episodeVideoHeight = widget.videoHeight == null
        ? null
        : l10n.onlineQualityHeight(widget.videoHeight!);
    final progress = item.progress;
    final failure = item.failure;
    final watchProgress = context
        .watchWatchProgress()
        .where(
          (progress) =>
              progress.torrentKey == sourceProgressKey(item.magnet) &&
              progress.fileIndex == item.fileIndex,
        )
        .firstOrNull;

    final (actionIcon, actionLabel, onAction) = switch (status) {
      DownloadStatus.completed => (
        PixelGlyph.play,
        l10n.downloadWatchButton,
        () => widget.onWatch(item),
      ),
      DownloadStatus.downloading || DownloadStatus.queued => (
        PixelGlyph.pause,
        l10n.downloadPauseButton,
        () => cubit.pause(item.id),
      ),
      // Its own glyph: ▶ only ever means watching.
      DownloadStatus.paused => (
        PixelGlyph.download,
        l10n.downloadResumeButton,
        () => cubit.resume(item.id),
      ),
      DownloadStatus.failed => (
        PixelGlyph.refresh,
        l10n.commonRetry,
        () => cubit.retry(item.id),
      ),
    };
    final statusLabel = downloadStatusLabel(l10n, status);
    final inlineDetail = status == DownloadStatus.downloading
        ? item.totalBytes > 0
              ? '${(progress * 100).round()}%'
              : statusLabel
        : status == DownloadStatus.completed
        ? null
        : statusLabel;
    final numericProgress =
        status == DownloadStatus.downloading && item.totalBytes > 0;
    final detailColor = switch ((status, numericProgress)) {
      (DownloadStatus.downloading, true) => Theme.of(
        context,
      ).colorScheme.tertiary,
      (DownloadStatus.failed, _) => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    final titleStyle = Theme.of(context).textTheme.titleSmall;
    final detailStyle = Theme.of(context).textTheme.labelMedium;
    final summary = [
      semanticName,
      statusLabel,
      if (!completed && item.totalBytes > 0) '${(progress * 100).round()} %',
      if (failure != null) downloadFailureMessage(l10n, failure),
      if (watchProgress != null)
        watchProgress.isFinished
            ? l10n.watchProgressWatched
            : l10n.watchProgressStoppedAt(
                formatPlaybackPosition(watchProgress.position),
                formatPlaybackPosition(watchProgress.duration),
              ),
    ].join(', ');

    final row = FocusableListRow(
      onDelete: () {
        if (widget.disabled) return;
        if (widget.selecting) {
          widget.onDeleteSelected();
        } else {
          _confirmDelete(context);
        }
      },
      filled: _menuOpen || (widget.selecting && widget.selected),
      onTap: widget.disabled
          ? null
          : widget.selecting
          ? widget.onSelect
          : completed
          ? () => widget.onWatch(item)
          : null,
      onLongPress: widget.disabled || widget.selecting ? null : _menu.open,
      onSecondaryTap: widget.disabled || widget.selecting ? null : _menu.open,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: _downloadRowContentHeight(context, titleStyle, detailStyle),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  label: summary,
                  customSemanticsActions: widget.disabled
                      ? null
                      : {
                          CustomSemanticsAction(label: l10n.commonMoreActions):
                              _menu.open,
                        },
                  child: ExcludeSemantics(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final progressWidth =
                            numericProgress && watchProgress != null
                            ? _textSize(
                                    context,
                                    detailStyle,
                                    text: inlineDetail!,
                                  ).width +
                                  8
                            : 0.0;
                        final watchWidth = math.max(
                          0.0,
                          numericProgress
                              ? (constraints.maxWidth - progressWidth - 8) / 2
                              : constraints.maxWidth / 2,
                        );
                        return Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    fit: FlexFit.loose,
                                    child: Tooltip(
                                      // Long press belongs to the row's actions menu.
                                      triggerMode: TooltipTriggerMode.manual,
                                      message: name,
                                      child: Text(
                                        downloadEpisode(l10n, item),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: titleStyle,
                                      ),
                                    ),
                                  ),
                                  if (episodeVideoHeight != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      episodeVideoHeight,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: detailStyle?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (inlineDetail != null) ...[
                              const SizedBox(width: 8),
                              if (numericProgress)
                                Text(
                                  inlineDetail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: detailStyle?.copyWith(
                                    color: detailColor,
                                  ),
                                )
                              else
                                Flexible(
                                  fit: FlexFit.tight,
                                  child: Text(
                                    inlineDetail,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                    style: detailStyle?.copyWith(
                                      color: detailColor,
                                    ),
                                  ),
                                ),
                            ],
                            if (watchProgress != null) ...[
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: watchWidth,
                                ),
                                child: Tooltip(
                                  triggerMode: TooltipTriggerMode.manual,
                                  message: watchProgress.isFinished
                                      ? l10n.watchProgressWatched
                                      : l10n.watchProgressStoppedAt(
                                          formatPlaybackPosition(
                                            watchProgress.position,
                                          ),
                                          formatPlaybackPosition(
                                            watchProgress.duration,
                                          ),
                                        ),
                                  child: watchProgress.isFinished
                                      ? PixelIcon(
                                          PixelGlyph.check,
                                          size: 14,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        )
                                      : Text(
                                          [
                                            formatPlaybackPosition(
                                              watchProgress.position,
                                            ),
                                            if (watchProgress.duration !=
                                                Duration.zero)
                                              formatPlaybackPosition(
                                                watchProgress.duration,
                                              ),
                                          ].join(' / '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.end,
                                          style: detailStyle?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MenuAnchor(
                controller: _menu,
                onOpen: () => _setMenuOpen(true),
                onClose: () => _setMenuOpen(false),
                alignmentOffset: const Offset(-176, 0),
                menuChildren: [
                  if (!completed)
                    MenuItemButton(
                      key: const Key('download_status'),
                      onPressed: widget.disabled
                          ? null
                          : () => _showDownloadStatus(context, itemId: item.id),
                      child: Text(l10n.downloadStatusDetails),
                    ),
                  MenuItemButton(
                    key: const Key('download_delete'),
                    onPressed: widget.disabled
                        ? null
                        : () => _confirmDelete(context),
                    child: Text(asksForMore(l10n.downloadDeleteButton)),
                  ),
                ],
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: DitherSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: widget.selecting
                        ? Checkbox(
                            key: ValueKey('download_delete_check_${item.id}'),
                            value: widget.selected,
                            onChanged: widget.disabled
                                ? null
                                : (_) => widget.onSelect(),
                          )
                        : Semantics(
                            key: const ValueKey('action'),
                            label: '$actionLabel: $semanticName',
                            button: true,
                            excludeSemantics: true,
                            onTap: widget.disabled ? null : onAction,
                            child: IconButton(
                              key: ValueKey('download_action_${item.id}'),
                              constraints: const BoxConstraints.tightFor(
                                width: 48,
                                height: 48,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: actionLabel,
                              icon: PixelIcon(
                                actionIcon,
                                size: 16,
                                color: completed
                                    ? null
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                              onPressed: widget.disabled ? null : onAction,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      checked: widget.selecting ? widget.selected : null,
      enabled: widget.selecting ? !widget.disabled : null,
      label: widget.selecting ? summary : null,
      onTap: widget.selecting && !widget.disabled ? widget.onSelect : null,
      child: ExcludeSemantics(excluding: widget.selecting, child: row),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    await confirmDownloadDeletion(context, [
      widget.item,
    ], downloadName(AppLocalizations.of(context), widget.item));
  }
}

double _downloadRowContentHeight(
  BuildContext context,
  TextStyle? titleStyle,
  TextStyle? detailStyle,
) => math.max(
  48.0,
  math.max(
    _textSize(context, titleStyle).height,
    _textSize(context, detailStyle).height,
  ),
);

Size _textSize(BuildContext context, TextStyle? style, {String text = 'Mg'}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  );
  try {
    painter.layout();
    return painter.size;
  } finally {
    painter.dispose();
  }
}

/// Sizes, and while downloading how long is left at what speed; peers
/// only when there are none, which is why it stands. An online episode has
/// no peers, and its size is a guess (`~`) until it is done, or unknown
/// before it starts.
String _facts(AppLocalizations l10n, DownloadItem item) {
  final finished = item.status == DownloadStatus.completed;
  final total = item.totalBytes <= 0
      ? null
      : [
          if (item.isOnline && !finished) '~',
          formatByteSize(l10n, item.totalBytes),
        ].join();
  final loaded = [formatByteSize(l10n, item.downloadedBytes), ?total];
  final facts = switch (item.status) {
    DownloadStatus.completed => total ?? '',
    // Nothing of it is here yet: only how big it will be.
    DownloadStatus.queued when item.downloadedBytes == 0 => total ?? '',
    DownloadStatus.downloading => [
      if (item.totalBytes > 0) '${(item.progress * 100).round()}%',
      if (item.totalBytes > 0)
        loaded.join(' / ')
      else if (item.downloadedBytes > 0)
        formatByteSize(l10n, item.downloadedBytes),
      if (item.peers == 0 && !item.isOnline)
        l10n.downloadNoPeers
      else ...[
        ?_timeLeft(l10n, item),
        formatTransferRate(l10n, item.downloadRateBytesPerSecond),
      ],
    ].join(' · '),
    _ => loaded.join(' / '),
  };
  return facts;
}

/// "~3 min" at the current speed; null while there is no speed to go by.
String? _timeLeft(AppLocalizations l10n, DownloadItem item) {
  final rate = item.downloadRateBytesPerSecond;
  final left = item.totalBytes - item.downloadedBytes;
  if (rate <= 0 || left <= 0) return null;
  final seconds = left / rate;
  if (seconds < 60) return l10n.downloadTimeLeftUnderMinute;
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return l10n.downloadTimeLeftMinutes(minutes);
  return l10n.downloadTimeLeftHours(minutes ~/ 60, minutes % 60);
}

int _byEpisode(DownloadItem left, DownloadItem right) {
  final a = episodeNumberFromFileName(left.fileName);
  final b = episodeNumberFromFileName(right.fileName);
  if (a != null && b != null && a != b) return a.compareTo(b);
  return left.fileName.compareTo(right.fileName);
}
