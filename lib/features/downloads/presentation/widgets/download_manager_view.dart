import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_state.dart';
import 'package:iris/features/downloads/presentation/widgets/download_deletion_dialog.dart';
import 'package:iris/features/downloads/presentation/widgets/download_files.dart';
import 'package:iris/features/downloads/presentation/widgets/download_labels.dart';
import 'package:iris/features/downloads/presentation/widgets/download_library_header.dart';
import 'package:iris/features/downloads/presentation/widgets/download_selection_footer.dart';
import 'package:iris/features/downloads/presentation/widgets/download_status_label.dart';
import 'package:iris/features/downloads/presentation/widgets/download_title_widgets.dart';
import 'package:iris/features/settings/presentation/anime_title_labels.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/haptics/app_haptics.dart';
import 'package:iris/shared/online/online_source_link.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/desktop_platform.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/adaptive/show_app_dialog.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/busy_button_child.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_list.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/focusable_list_row.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';
import 'package:iris/shared/widgets/quality_badge.dart';
import 'package:iris/shared/widgets/row_menu_button.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/status_views.dart';

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
  bool _hadGalleryTitles = false;

  void _galleryEmptied() {
    if (!mounted || !_hadGalleryTitles) return;
    setState(() => _hadGalleryTitles = false);
  }

  @override
  Widget build(BuildContext context) {
    final splitView = WindowSizeClass.of(
      context,
    ).isAtLeast(WindowSizeClass.expanded);
    final scheme = Theme.of(context).colorScheme;
    return BlocBuilder<DownloadManagerCubit, DownloadManagerState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context);
        final (
          Object? placeholderKey,
          Widget? placeholder,
        ) = state.downloads.isEmpty && state.isLoading
            ? ('loading', LoadingView(semanticsLabel: l10n.downloadsLoading))
            : state.downloads.isEmpty && state.hasError
            ? (
                'error',
                RetryView(
                  message: l10n.downloadManagerUnableToLoad,
                  onRetry: context.read<DownloadManagerCubit>().load,
                ),
              )
            : (null, null);
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
        if (placeholder != null) {
          _hadGalleryTitles = false;
        } else if (!splitView && titles.isNotEmpty) {
          _hadGalleryTitles = true;
        }
        final holdGallery =
            !splitView &&
            titles.isEmpty &&
            _hadGalleryTitles &&
            !MediaQuery.disableAnimationsOf(context);
        final showSplit = splitView && placeholder == null && titles.isNotEmpty;
        final (Object libraryKey, Widget library) = placeholder != null
            ? (placeholderKey!, placeholder)
            : splitView
            ? (
                'split',
                _SplitLibrary(
                  titles: titles,
                  onWatch: widget.onWatch,
                  onOpenAnime: widget.onOpenAnime,
                  onDownloadMore: widget.onDownloadMore,
                  onBrowseCatalog: widget.onBrowseCatalog,
                ),
              )
            : titles.isEmpty && !holdGallery
            ? ('empty', _EmptyLibrary(onBrowseCatalog: widget.onBrowseCatalog))
            : (
                'gallery',
                DownloadLibraryGallery(
                  titles: titles,
                  onOpenTitle: widget.onOpenTitle,
                  onEmptied: _galleryEmptied,
                ),
              );
        final hasActive = state.downloads.any(
          (item) => item.status == DownloadStatus.downloading,
        );
        final hasFailed = state.downloads.any(
          (item) => item.status == DownloadStatus.failed,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DownloadLibraryHeader(
              queueCount: state.queue.length,
              showQueue: state.downloads.any(
                (item) => item.status != DownloadStatus.completed,
              ),
              hasActive: hasActive,
              hasFailed: hasFailed,
              onQueue: widget.onOpenQueue,
              onFiles: () async {
                final title = await showDownloadFiles(context);
                if (title != null && context.mounted) widget.onOpenTitle(title);
              },
            ),
            if (showSplit) ...[
              const SizedBox(height: 12),
              Divider(
                height: 1,
                thickness: 1,
                color: DetailLayout.ruleColor(scheme),
              ),
            ] else
              const SizedBox(height: 16),
            Expanded(
              key: const ValueKey('downloads_library_body'),
              child: DitherSwitcher(
                expand: true,
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(key: ValueKey(libraryKey), child: library),
              ),
            ),
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
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontFamily: DetailLayout.sansFont,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.downloadsEmpty,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: DetailLayout.sansFont,
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

class _SplitLibrary extends StatefulWidget {
  const _SplitLibrary({
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
  State<_SplitLibrary> createState() => _SplitLibraryState();
}

class _SplitLibraryState extends State<_SplitLibrary> {
  late String? _selectedKey = widget.titles.firstOrNull?.key;

  @override
  void didUpdateWidget(covariant _SplitLibrary oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedKey ??= widget.titles.firstOrNull?.key;
  }

  @override
  Widget build(BuildContext context) {
    final selectedKey = _selectedKey;
    if (selectedKey == null) {
      return _EmptyLibrary(onBrowseCatalog: widget.onBrowseCatalog);
    }
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.titles
        .where((title) => title.key == selectedKey)
        .firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidebarWidth = constraints.maxWidth >= 1000 ? 276.0 : 244.0;
        final details = DitherSwitcher(
          expand: true,
          duration: const Duration(milliseconds: 240),
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
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: sidebarWidth,
              child: DitherList<DownloadTitle>(
                key: const Key('download_poster_list'),
                padding: const EdgeInsets.only(top: 16, right: 16, bottom: 32),
                items: widget.titles,
                keyOf: (title) => title.key,
                itemBuilder: (context, title) => DownloadPosterOption(
                  title: title,
                  selected: title.key == selectedKey,
                  onTap: () {
                    if (_selectedKey == title.key) return;
                    AppHaptics.selection();
                    setState(() => _selectedKey = title.key);
                  },
                ),
                rowSpacing: 6,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: DetailLayout.ruleColor(scheme),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 16, left: 24),
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 780),
                    child: details,
                  ),
                ),
              ),
            ),
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
    final name = title == null
        ? ''
        : watchAnimeTitleLabels(context, title.animeTitles).primary;
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
              await confirmDownloadDeletion(context, items, name, all: true);
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
            if (item == null) {
              return Text(
                l10n.downloadTitleEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: DetailLayout.sansFont,
                ),
              );
            }
            final number = downloadEpisodeNumber(item);
            final factsText = _facts(l10n, item);
            final factsSans = theme.textTheme.bodySmall?.copyWith(
              fontFamily: DetailLayout.sansFont,
              color: scheme.onSurfaceVariant,
            );
            final factsMono = DetailLayout.monoTelemetryStyle(
              theme.textTheme.bodySmall,
              color: scheme.onSurfaceVariant,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (number != null) ...[
                  Text(
                    l10n.downloadEpisodeLabel(
                      number.toString().padLeft(2, '0'),
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: DetailLayout.sansFont,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  downloadStatusLabel(l10n, item.status),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontFamily: DetailLayout.sansFont,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (factsText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  PixelSeparatedText.spans([
                    for (final part in factsText.split(' · '))
                      DetailLayout.mixedDataSpan(
                        part,
                        sansStyle: factsSans,
                        monoStyle: factsMono,
                      ),
                  ], style: factsSans),
                ],
                if (item.failure case final failure?) ...[
                  const SizedBox(height: 8),
                  Text(
                    downloadFailureMessage(l10n, failure),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: DetailLayout.sansFont,
                      color: scheme.error,
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
  int? _deletingCount;
  int _failureCount = 0;

  bool get _busy => _deletingCount != null;

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

  void _startSelection({bool fromHold = false}) {
    if (_selecting || widget.title == null) return;
    if (fromHold) AppHaptics.medium();
    setState(() => _selecting = true);
    _focus.requestFocus();
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
    final count = _selected.length;
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
    if (_selected.length != count) AppHaptics.selection();
  }

  void _toggleGroup(Iterable<DownloadItem> items) {
    if (_busy) return;
    final ids = items.map((item) => item.id).toSet();
    if (ids.isEmpty) return;
    setState(() {
      _failureCount = 0;
      if (ids.every(_selected.contains)) {
        _selected.removeAll(ids);
      } else {
        _selected.addAll(ids);
      }
      _anchor = null;
    });
    AppHaptics.selection();
  }

  Future<void> _deleteSelected() async {
    if (_busy || _selected.isEmpty) return;
    final items = widget.downloads
        .where((item) => _selected.contains(item.id))
        .toList();
    final title = widget.title;
    if (items.isEmpty || title == null) return;
    final name = resolveAnimeTitles(
      AppLocalizations.of(context),
      title.animeTitles,
      readAnimeTitleLanguage(context),
    ).primary;
    setState(() => _deletingCount = items.length);
    final failed = await confirmDownloadDeletion(
      context,
      items,
      name,
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
      _deletingCount = null;
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
    final scheme = theme.colorScheme;
    final rule = BorderSide(color: DetailLayout.ruleColor(scheme));
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
            onSelect: _startSelection,
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
                  fontFamily: DetailLayout.sansFont,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          : null,
      keyOf: (row) => row.$1,
      itemBuilder: (context, row) => row.$2,
      items: [
        for (var r = 0; r < releases.length; r++) ...[
          (
            'release:${downloadSourceKey(releases[r].first.magnet)}',
            Padding(
              padding: EdgeInsets.only(top: r == 0 ? 0 : 20, bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _ReleaseFacts(
                      item: releases[r].first,
                      videoHeight:
                          sharedHeights[downloadSourceKey(
                            releases[r].first.magnet,
                          )],
                    ),
                  ),
                  if (releases.length > 1)
                    SizedBox(
                      height: 40,
                      child: DitherSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _selecting
                            ? Checkbox(
                                key: ValueKey(
                                  'download_group_select_${downloadSourceKey(releases[r].first.magnet)}',
                                ),
                                tristate: true,
                                value:
                                    releases[r].every(
                                      (item) => _selected.contains(item.id),
                                    )
                                    ? true
                                    : releases[r].any(
                                        (item) => _selected.contains(item.id),
                                      )
                                    ? null
                                    : false,
                                semanticLabel: downloadSourceLabel(
                                  releases[r].first,
                                ),
                                onChanged: _busy
                                    ? null
                                    : (_) => _toggleGroup(releases[r]),
                              )
                            : onDownloadMore != null
                            ? TextButton.icon(
                                key: ValueKey(
                                  'download_more_${downloadSourceKey(releases[r].first.magnet)}',
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: scheme.onSurfaceVariant,
                                  padding: const EdgeInsets.only(left: 8),
                                  minimumSize: const Size(0, 40),
                                  textStyle: theme.textTheme.bodySmall
                                      ?.copyWith(
                                        fontFamily: DetailLayout.sansFont,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                                onPressed: () =>
                                    onDownloadMore(releases[r].first),
                                icon: PixelIcon(
                                  PixelGlyph.download,
                                  size: 13,
                                  color: scheme.onSurfaceVariant,
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
          for (var i = 0; i < releases[r].length; i++)
            (
              'file:${releases[r][i].id}',
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: rule.color.withValues(alpha: 0.75)),
                  ),
                ),
                child: _DownloadRow(
                  key: ValueKey(releases[r][i].id),
                  item: releases[r][i],
                  videoHeight:
                      sharedHeights[downloadSourceKey(
                            releases[r].first.magnet,
                          )] ==
                          null
                      ? releases[r][i].videoHeight
                      : null,
                  onWatch: widget.onWatch,
                  selecting: _selecting,
                  selected: _selected.contains(releases[r][i].id),
                  disabled:
                      _busy || manager.deletingIds.contains(releases[r][i].id),
                  onSelect: () => _toggle(releases[r][i].id),
                  onDeleteSelected: _deleteSelected,
                ),
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
                  onHoldToSelect: title == null || _selecting
                      ? null
                      : () => _startSelection(fromHold: true),
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
              Builder(
                builder: (context) {
                  final duration = motionDuration(
                    context,
                    const Duration(milliseconds: 180),
                  );
                  final banner = _selecting && _failureCount > 0
                      ? Semantics(
                          liveRegion: true,
                          child: Text(
                            l10n.downloadDeleteSelectionFailed(_failureCount),
                            textAlign: TextAlign.end,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: DetailLayout.sansFont,
                              color: scheme.error,
                            ),
                          ),
                        )
                      : const SizedBox.shrink();
                  if (duration == Duration.zero) return banner;
                  return AnimatedSize(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: banner,
                  );
                },
              ),
              DownloadSelectionFooter(
                visible: _selecting,
                child: FilledButton(
                  key: const Key('download_delete_selected'),
                  style: busyButtonStyle(
                    busy: _busy && manager.deletingIds.isNotEmpty,
                  ),
                  onPressed: _busy || _selected.isEmpty
                      ? null
                      : _deleteSelected,
                  child: BusyButtonChild(
                    l10n.downloadDeleteSelected(
                      _deletingCount ?? _selected.length,
                    ),
                    busy: _busy && manager.deletingIds.isNotEmpty,
                    busyLabel: l10n.downloadDeleting,
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
    final theme = Theme.of(context);
    final label = displayReleaseLabel(
      downloadSourceLabel(item),
      shownVideoHeight: videoHeight,
    );
    return Tooltip(
      message: item.sourceTitle,
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: DetailLayout.sansFont,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (videoHeight case final height?) ...[
              const SizedBox(width: 8),
              QualityBadge(l10n.onlineQualityHeight(height)),
            ],
          ],
        ),
      ),
    );
  }
}

int? _sharedReleaseHeight(List<DownloadItem> release) {
  if (release.isEmpty) return null;
  final height = release.first.videoHeight;
  return height != null &&
          height > 0 &&
          release.every((item) => item.videoHeight == height)
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

/// One downloaded or queued file inside a release block.
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cubit = context.read<DownloadManagerCubit>();
    final item = widget.item;
    final status = item.status;
    final completed = status == DownloadStatus.completed;
    final titleLanguage = watchAnimeTitleLanguage(context);
    final name = downloadName(l10n, item, titleLanguage: titleLanguage);
    final semanticName = downloadSemanticName(
      l10n,
      item,
      titleLanguage: titleLanguage,
    );
    final episodeLabel = downloadEpisode(l10n, item);
    final episodeVideoHeight =
        widget.videoHeight == null || widget.videoHeight! <= 0
        ? null
        : l10n.onlineQualityHeight(widget.videoHeight!);
    final progress = downloadDisplayProgress(item);
    final failure = item.failure;
    final watchProgress = context
        .watchWatchProgress()
        .where(
          (progress) =>
              progress.torrentKey == sourceProgressKey(item.magnet) &&
              progress.fileIndex == item.fileIndex,
        )
        .firstOrNull;
    final watched = completed && (watchProgress?.isFinished ?? false);
    final partialWatch = watchProgress != null && !watchProgress.isFinished;

    final (actionIcon, actionLabel, onAction) = switch (status) {
      DownloadStatus.completed => (null, null, null),
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
      (DownloadStatus.downloading, true) => scheme.tertiary,
      (DownloadStatus.failed, _) => scheme.error,
      _ => scheme.onSurfaceVariant,
    };

    final sizeDetail = switch (status) {
      DownloadStatus.completed when item.totalBytes > 0 => formatByteSize(
        l10n,
        item.totalBytes,
        compact: true,
      ),
      DownloadStatus.downloading when item.totalBytes > 0 =>
        '${formatByteSize(l10n, item.downloadedBytes, compact: true)} / '
            '${item.isOnline ? '~' : ''}${formatByteSize(l10n, item.totalBytes, compact: true)}',
      DownloadStatus.paused
          when item.totalBytes > 0 && item.downloadedBytes > 0 =>
        '${formatByteSize(l10n, item.downloadedBytes, compact: true)} / '
            '${item.isOnline ? '~' : ''}${formatByteSize(l10n, item.totalBytes, compact: true)}',
      DownloadStatus.queued when item.totalBytes > 0 => formatByteSize(
        l10n,
        item.totalBytes,
        compact: true,
      ),
      _ => null,
    };
    final speedDetail =
        status == DownloadStatus.downloading &&
            item.downloadRateBytesPerSecond > 0
        ? formatTransferRate(l10n, item.downloadRateBytesPerSecond)
        : null;
    final watchTimeText = partialWatch
        ? [
            formatPlaybackPosition(watchProgress.position),
            if (watchProgress.duration != Duration.zero)
              formatPlaybackPosition(watchProgress.duration),
          ].join(' / ')
        : null;

    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: DetailLayout.sansFont,
      fontSize: 15,
      fontWeight: watched ? FontWeight.w400 : FontWeight.w500,
      color: watched ? scheme.onSurfaceVariant : scheme.onSurface,
    );
    final detailSans = theme.textTheme.bodySmall?.copyWith(
      fontFamily: DetailLayout.sansFont,
      color: scheme.onSurfaceVariant,
    );
    final detailMono = DetailLayout.monoTelemetryStyle(
      theme.textTheme.bodySmall,
      color: scheme.onSurfaceVariant,
    );

    final double? barProgress = switch (status) {
      DownloadStatus.downloading when item.totalBytes > 0 => progress,
      DownloadStatus.paused
          when item.totalBytes > 0 && item.downloadedBytes > 0 =>
        progress,
      DownloadStatus.completed
          when partialWatch && watchProgress.duration > Duration.zero =>
        watchProgress.fraction,
      _ => null,
    };
    final barColor = status == DownloadStatus.downloading
        ? scheme.tertiary
        : scheme.onSurfaceVariant;
    final barHeight = status == DownloadStatus.downloading ? 3.0 : 2.0;

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

    final metadataItems = <Widget>[
      if (inlineDetail != null)
        Text(
          inlineDetail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: numericProgress
              ? detailMono?.copyWith(
                  color: detailColor,
                  fontWeight: FontWeight.w500,
                )
              : detailSans?.copyWith(color: detailColor),
        ),
      if (sizeDetail != null)
        Text(
          sizeDetail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: detailMono,
        ),
      if (speedDetail != null)
        Text(
          speedDetail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: detailMono,
        ),
      if (watchTimeText != null)
        Text(
          watchTimeText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: detailMono,
        ),
    ];
    final showMetaDots =
        MediaQuery.textScalerOf(context).scale(16) < 22 &&
        metadataItems.length > 1;
    final hasMetadata = metadataItems.isNotEmpty;

    final menuChildren = [
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
        onPressed: widget.disabled ? null : () => _confirmDelete(context, name),
        child: Text(asksForMore(l10n.downloadDeleteButton)),
      ),
    ];

    final row = FocusableListRow(
      onDelete: () {
        if (widget.disabled) return;
        if (widget.selecting) {
          widget.onDeleteSelected();
        } else {
          _confirmDelete(context, name);
        }
      },
      filled: _menuOpen || (widget.selecting && widget.selected),
      onTap: widget.disabled
          ? null
          : widget.selecting
          ? widget.onSelect
          : completed
          ? () => widget.onWatch(item)
          : status == DownloadStatus.failed
          ? () => _showDownloadStatus(context, itemId: item.id)
          : null,
      onLongPress: widget.disabled || widget.selecting
          ? null
          : () {
              if (_menu.isOpen) return;
              _menu.open();
              if (_menu.isOpen) AppHaptics.medium();
            },
      onSecondaryTap: widget.disabled || widget.selecting ? null : _menu.open,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 62),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
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
                              CustomSemanticsAction(
                                label: l10n.commonMoreActions,
                              ): _menu.open,
                            },
                      child: ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Tooltip(
                                    // Long press belongs to the row's actions menu.
                                    triggerMode: TooltipTriggerMode.manual,
                                    message: name,
                                    child: Text(
                                      episodeLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: titleStyle,
                                    ),
                                  ),
                                ),
                                if (episodeVideoHeight != null) ...[
                                  const SizedBox(width: 8),
                                  QualityBadge(episodeVideoHeight),
                                ],
                                if (watched) ...[
                                  const SizedBox(width: 8),
                                  PixelIcon(
                                    PixelGlyph.check,
                                    size: 14,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ],
                              ],
                            ),
                            if (hasMetadata) ...[
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: showMetaDots ? 6 : 10,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  for (
                                    var i = 0;
                                    i < metadataItems.length;
                                    i++
                                  ) ...[
                                    if (showMetaDots && i > 0)
                                      SizedBox.square(
                                        dimension: 2,
                                        child: ColoredBox(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    metadataItems[i],
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  DitherSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: widget.selecting
                        ? SizedBox(
                            key: const ValueKey('selecting'),
                            width: 48,
                            height: 48,
                            child: Checkbox(
                              key: ValueKey('download_delete_check_${item.id}'),
                              value: widget.selected,
                              onChanged: widget.disabled
                                  ? null
                                  : (_) => widget.onSelect(),
                            ),
                          )
                        : Row(
                            key: ValueKey(
                              'action_${switch (status) {
                                DownloadStatus.queued || DownloadStatus.downloading => 'active',
                                _ => status.name,
                              }}',
                            ),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (actionIcon != null &&
                                  actionLabel != null &&
                                  onAction != null)
                                Semantics(
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
                                      color: scheme.onSurface,
                                    ),
                                    onPressed: widget.disabled
                                        ? null
                                        : onAction,
                                  ),
                                ),
                              RowMenuButton(
                                key: ValueKey('download_row_menu_${item.id}'),
                                controller: _menu,
                                onOpenChanged: _setMenuOpen,
                                iconColor: scheme.onSurfaceVariant,
                                tooltip: l10n.commonMoreActions,
                                semanticLabel:
                                    '$semanticName, ${l10n.commonMoreActions}',
                                menuChildren: menuChildren,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            if (barProgress != null && !widget.selecting)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SegmentedBar(
                  value: barProgress,
                  height: barHeight,
                  segment: 6,
                  gap: 0,
                  color: barColor,
                  trackColor: Colors.transparent,
                ),
              ),
          ],
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

  Future<void> _confirmDelete(BuildContext context, String name) async {
    await confirmDownloadDeletion(context, [widget.item], name);
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
      if (item.totalBytes > 0)
        '${(downloadDisplayProgress(item) * 100).round()}%',
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
  final a = downloadEpisodeNumber(left) ?? double.infinity;
  final b = downloadEpisodeNumber(right) ?? double.infinity;
  final byNumber = a.compareTo(b);
  if (byNumber != 0) return byNumber;
  final byName = left.fileName.compareTo(right.fileName);
  return byName == 0 ? left.fileIndex.compareTo(right.fileIndex) : byName;
}
