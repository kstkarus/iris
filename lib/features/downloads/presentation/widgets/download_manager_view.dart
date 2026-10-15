import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_failure.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_line.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/online/online_source_link.dart';
import 'package:iris/features/downloads/domain/entities/download_storage_usage.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_state.dart';
import 'package:iris/features/downloads/presentation/widgets/download_status_label.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/desktop_platform.dart';
import 'package:iris/shared/utils/episode_number.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/features/downloads/presentation/widgets/download_title_widgets.dart';
import 'package:iris/shared/widgets/focusable_list_row.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/row_menu_button.dart';
import 'package:iris/shared/widgets/section_label.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/spec_table.dart';
import 'package:iris/shared/widgets/status_views.dart';
import 'package:iris/shared/widgets/dither_list.dart';

class DownloadManagerView extends StatefulWidget {
  const DownloadManagerView({
    required this.onWatch,
    required this.onBrowseCatalog,
    required this.onOpenTitle,
    this.titleKey,
    this.onTitleDeleted,
    super.key,
  });

  final ValueChanged<DownloadItem> onWatch;
  final ValueChanged<DownloadTitle> onOpenTitle;
  final String? titleKey;
  final VoidCallback? onTitleDeleted;

  /// Where an empty list leads: episodes are downloaded from a title's
  /// sources.
  final VoidCallback onBrowseCatalog;

  @override
  State<DownloadManagerView> createState() => _DownloadManagerViewState();
}

class _DownloadManagerViewState extends State<DownloadManagerView> {
  /// Each file's status when the list last changed, to tell what changed.
  final _lastStatuses = <String, DownloadStatus>{};

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DownloadManagerCubit, DownloadManagerState>(
      listenWhen: (previous, current) =>
          previous.downloads != current.downloads,
      listener: _announceFinished,
      builder: (context, state) {
        if (state.isLoading && state.downloads.isEmpty) {
          return LoadingView(
            semanticsLabel: AppLocalizations.of(context).downloadsLoading,
          );
        }
        if (state.hasError && state.downloads.isEmpty) {
          final l10n = AppLocalizations.of(context);
          return RetryView(
            message: l10n.downloadManagerUnableToLoad,
            onRetry: context.read<DownloadManagerCubit>().load,
          );
        }
        final titles = downloadTitles(state.downloads);
        if (widget.titleKey case final key?) {
          final title = titles.where((title) => title.key == key).firstOrNull;
          return _Episodes(
            downloads: title?.items ?? const [],
            onWatch: widget.onWatch,
            title: title,
            onTitleDeleted: widget.onTitleDeleted,
          );
        }
        if (titles.isEmpty) {
          return _EmptyLibrary(onBrowseCatalog: widget.onBrowseCatalog);
        }
        if (isDesktopPlatform) {
          return _DesktopLibrary(titles: titles, onWatch: widget.onWatch);
        }
        return DownloadLibraryGallery(
          titles: titles,
          onOpenTitle: widget.onOpenTitle,
          menu: const _DownloadsMenu(showStorage: true),
        );
      },
    );
  }

  /// Tells a screen reader when a file finishes or fails; the percentage
  /// itself is not announced, it would never stop talking.
  void _announceFinished(BuildContext context, DownloadManagerState state) {
    final l10n = AppLocalizations.of(context);
    final view = View.of(context);
    final direction = Directionality.of(context);
    for (final item in state.downloads) {
      final before = _lastStatuses[item.id];
      _lastStatuses[item.id] = item.status;
      if (before == null || before == item.status) continue;
      final message = switch (item.status) {
        DownloadStatus.completed => l10n.downloadAnnounceCompleted(
          downloadName(l10n, item),
        ),
        DownloadStatus.failed => l10n.downloadAnnounceFailed(
          downloadName(l10n, item),
        ),
        _ => null,
      };
      if (message != null) {
        SemanticsService.sendAnnouncement(view, message, direction);
      }
    }
  }
}

/// "Frieren, Episode 6": the title and the episode read from the file
/// name, or the file's own name when it has no number.
String downloadName(AppLocalizations l10n, DownloadItem item) =>
    '${item.animeTitle}, ${downloadEpisode(l10n, item)}';

/// The episode read from the file name, or the file's own name.
String downloadEpisode(AppLocalizations l10n, DownloadItem item) {
  final number = episodeNumberFromFileName(item.fileName);
  return number == null
      ? fileDisplayName(item.fileName)
      : l10n.downloadEpisodeLabel(number.toString().padLeft(2, '0'));
}

class _Storage extends StatelessWidget {
  const _Storage({required this.usage});

  final DownloadStorageUsage? usage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String size(int? bytes) =>
        bytes == null ? '—' : formatByteSize(l10n, bytes);
    final rows = [
      SpecRow(l10n.downloadStorageTotal, size(usage?.totalBytes)),
      SpecRow(l10n.downloadStorageContent, size(usage?.downloadsBytes)),
      SpecRow(
        l10n.downloadStorageCache,
        size(usage?.cacheBytes),
        trailing: (usage?.cacheBytes ?? 0) > 0
            ? TextButton(
                key: const Key('download_storage_clear_cache_button'),
                onPressed: () => _clearCache(context),
                child: Text(l10n.downloadStorageClearCache),
              )
            : null,
      ),
    ];
    final compact =
        MediaQuery.sizeOf(context).width < 680 ||
        MediaQuery.textScalerOf(context).scale(16) > 22;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.downloadStorageTitle),
        const SizedBox(height: 12),
        if (!compact)
          SpecTable(labelWidth: 196, rows: rows)
        else
          for (final row in rows) ...[
            const SegmentedRule(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.label, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(row.value, style: theme.textTheme.bodyMedium),
                  ?row.trailing,
                ],
              ),
            ),
          ],
        const SizedBox(height: 8),
        Text(l10n.downloadStorageCacheHint, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

Future<void> _clearCache(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final cleared = await context.read<DownloadManagerCubit>().clearCache();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        cleared
            ? l10n.downloadStorageCacheCleared
            : l10n.downloadStorageCacheBusy,
      ),
    ),
  );
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onBrowseCatalog});
  final VoidCallback onBrowseCatalog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.downloadLibraryCount(0),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const _DownloadsMenu(showStorage: true),
          ],
        ),
        const SizedBox(height: 8),
        const SegmentedRule(),
        const SizedBox(height: 24),
        Text(l10n.downloadsEmpty),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            key: const Key('downloads_browse_catalog'),
            onPressed: onBrowseCatalog,
            child: Text(l10n.commonBrowseCatalog),
          ),
        ),
      ],
    );
  }
}

class _DesktopLibrary extends StatefulWidget {
  const _DesktopLibrary({required this.titles, required this.onWatch});
  final List<DownloadTitle> titles;
  final ValueChanged<DownloadItem> onWatch;

  @override
  State<_DesktopLibrary> createState() => _DesktopLibraryState();
}

class _DesktopLibraryState extends State<_DesktopLibrary> {
  late String _selectedKey = widget.titles.first.key;

  @override
  void didUpdateWidget(covariant _DesktopLibrary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.titles.any((title) => title.key == _selectedKey)) {
      _selectedKey = widget.titles.first.key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.titles.firstWhere(
      (title) => title.key == _selectedKey,
    );
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 800;
        Widget option(DownloadTitle title) => DownloadPosterOption(
          title: title,
          selected: title.key == selected.key,
          onTap: () => setState(() => _selectedKey = title.key),
        );
        final details = DitherSwitcher(
          expand: true,
          child: _Episodes(
            key: ValueKey('download_episodes_${selected.key}'),
            title: selected,
            downloads: selected.items,
            onWatch: widget.onWatch,
            desktop: true,
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(
              l10n.downloadLibraryTitle,
              trailing: Text(
                widget.titles.length.toString().padLeft(2, '0'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            const SizedBox(height: 16),
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
    this.onTitleDeleted,
    this.showStorage = false,
  });
  final DownloadTitle? title;
  final VoidCallback? onTitleDeleted;
  final bool showStorage;

  @override
  State<_DownloadsMenu> createState() => _DownloadsMenuState();
}

class _DownloadsMenuState extends State<_DownloadsMenu> {
  final _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = widget.title;
    return RowMenuButton(
      key: Key(title == null ? 'download_library_menu' : 'download_title_menu'),
      controller: _controller,
      tooltip: l10n.commonMoreActions,
      menuChildren: [
        if (title != null)
          MenuItemButton(
            key: const Key('download_title_information'),
            onPressed: () =>
                _showDownloadInformation(context, titleKey: title.key),
            child: Text(l10n.downloadInformationAction),
          ),
        if (title != null && title.items.length > 1)
          MenuItemButton(
            key: const Key('download_title_delete_all'),
            onPressed: () async {
              final onDeleted = widget.onTitleDeleted;
              final items = context
                  .read<DownloadManagerCubit>()
                  .state
                  .downloads
                  .where((item) => downloadTitleKey(item) == title.key)
                  .toList();
              final removed = await confirmDownloadDeletion(
                context,
                items,
                title.name,
                all: true,
              );
              if (removed) onDeleted?.call();
            },
            child: Text(asksForMore(l10n.downloadDeleteAll)),
          ),
        if (widget.showStorage)
          MenuItemButton(
            key: const Key('download_storage_open'),
            onPressed: () => _showStorage(context),
            child: Text(asksForMore(l10n.downloadStorageTitle)),
          ),
      ],
    );
  }
}

Future<void> _showStorage(BuildContext context) async {
  final cubit = context.read<DownloadManagerCubit>();
  unawaited(cubit.refreshStorage());
  await showDialog<void>(
    context: context,
    builder: (context) => BlocProvider.value(
      value: cubit,
      child: AlertDialog(
        key: const Key('download_storage_dialog'),
        scrollable: true,
        content: SizedBox(
          width: 560,
          child: BlocBuilder<DownloadManagerCubit, DownloadManagerState>(
            builder: (context, state) => _Storage(usage: state.storageUsage),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).closeButtonTooltip),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showDownloadInformation(
  BuildContext context, {
  String? itemId,
  String? titleKey,
}) async {
  assert((itemId == null) != (titleKey == null));
  final cubit = context.read<DownloadManagerCubit>();
  final watchCubit = context.read<WatchProgressCubit?>();
  await showDialog<void>(
    context: context,
    builder: (context) {
      Widget dialog = _DownloadInformationDialog(
        itemId: itemId,
        titleKey: titleKey,
      );
      if (watchCubit != null) {
        dialog = BlocProvider<WatchProgressCubit>.value(
          value: watchCubit,
          child: dialog,
        );
      }
      return BlocProvider<DownloadManagerCubit>.value(
        value: cubit,
        child: dialog,
      );
    },
  );
}

class _DownloadInformationDialog extends StatelessWidget {
  const _DownloadInformationDialog({this.itemId, this.titleKey});

  final String? itemId;
  final String? titleKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const Key('download_information_dialog'),
      scrollable: true,
      title: Text(l10n.downloadInformation),
      content: SizedBox(
        width: 560,
        child: BlocBuilder<DownloadManagerCubit, DownloadManagerState>(
          builder: (context, state) {
            final items = itemId != null
                ? state.downloads.where((item) => item.id == itemId).toList()
                : state.downloads
                      .where((item) => downloadTitleKey(item) == titleKey)
                      .toList();
            final watched = context.watchWatchProgress();
            if (items.isEmpty) return Text(l10n.downloadTitleEmpty);
            final releases = _releases(items);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final release in releases) ...[
                  Text(
                    release.first.sourceTitle,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  for (final item in release) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.fileName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _facts(l10n, item),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (item.failure case final failure?) ...[
                      const SizedBox(height: 4),
                      Text(
                        _failureMessage(l10n, failure),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (watched
                            .where(
                              (progress) =>
                                  progress.torrentKey ==
                                      sourceProgressKey(item.magnet) &&
                                  progress.fileIndex == item.fileIndex,
                            )
                            .firstOrNull
                        case final progress?) ...[
                      const SizedBox(height: 8),
                      WatchProgressLine(
                        progress: progress,
                        showBar: false,
                        timesOnly: true,
                      ),
                    ],
                  ],
                  if (release != releases.last) const SizedBox(height: 20),
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

class _Episodes extends StatelessWidget {
  const _Episodes({
    required this.downloads,
    required this.onWatch,
    this.title,
    this.desktop = false,
    this.onTitleDeleted,
    super.key,
  });
  final List<DownloadItem> downloads;
  final DownloadTitle? title;
  final ValueChanged<DownloadItem> onWatch;
  final bool desktop;
  final VoidCallback? onTitleDeleted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = this.title;
    final releases = _releases(downloads);
    final menu = title != null
        ? _DownloadsMenu(
            title: title,
            onTitleDeleted: onTitleDeleted,
            showStorage: desktop,
          )
        : null;
    return DitherList<(String, Widget)>(
      key: ValueKey('download_episodes_list_${title?.key ?? ''}'),
      padding: const EdgeInsets.only(bottom: 32),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            DownloadTitleIdentity(
              title: title,
              showPoster: !desktop,
              trailing: desktop ? null : menu,
            ),
            SizedBox(height: desktop ? 24 : 28),
          ],
          SectionLabel(
            l10n.playerEpisodesTitle,
            trailing: desktop ? menu : null,
          ),
          SizedBox(height: desktop ? 8 : 12),
        ],
      ),
      keyOf: (row) => row.$1,
      itemBuilder: (context, row) => row.$2,
      items: [
        if (downloads.isEmpty)
          (
            'empty',
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Text(
                l10n.downloadTitleEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (final release in releases) ...[
            if (releases.length > 1)
              (
                'release:${downloadSourceKey(release.first.magnet)}',
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 16),
                  child: _ReleaseFacts(item: release.first),
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
                      onWatch: onWatch,
                    ),
                  ],
                ),
              ),
          ],
      ],
    );
  }
}

class _ReleaseFacts extends StatelessWidget {
  const _ReleaseFacts({required this.item});
  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final name = item.animeTitle;
    var label = name.isEmpty
        ? item.sourceTitle
        : item.sourceTitle
              .replaceAll(RegExp(RegExp.escape(name), caseSensitive: false), '')
              .trim();
    label = label
        .replaceAll(RegExp(r'[\[\]()]'), '')
        .replaceAll(RegExp(r'^\s*[·|—-]+|[·|—-]+\s*$'), '')
        .trim();
    if (label.isEmpty) label = item.sourceTitle;
    final dot = item.fileName.lastIndexOf('.');
    final extension = dot < 0 ? '' : item.fileName.substring(dot + 1);
    return Tooltip(
      message: item.sourceTitle,
      child: Text(
        [label, if (extension.isNotEmpty) extension].join(' · ').toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
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
  const _DownloadRow({required this.item, required this.onWatch, super.key});

  final DownloadItem item;
  final ValueChanged<DownloadItem> onWatch;

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
      name,
      statusLabel,
      if (!completed && item.totalBytes > 0) '${(progress * 100).round()} %',
      if (failure != null) _failureMessage(l10n, failure),
      if (watchProgress != null)
        watchProgress.isFinished
            ? l10n.watchProgressWatched
            : l10n.watchProgressStoppedAt(
                formatPlaybackPosition(watchProgress.position),
                formatPlaybackPosition(watchProgress.duration),
              ),
    ].join(', ');

    return FocusableListRow(
      onDelete: () => _confirmDelete(context),
      filled: _menuOpen,
      onTap: completed ? () => widget.onWatch(item) : null,
      onLongPress: _menu.open,
      onSecondaryTap: _menu.open,
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
                  customSemanticsActions: {
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
                                          formatPlaybackPosition(
                                            watchProgress.position,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                  MenuItemButton(
                    key: const Key('download_information'),
                    onPressed: () =>
                        _showDownloadInformation(context, itemId: item.id),
                    child: Text(l10n.downloadInformationAction),
                  ),
                  MenuItemButton(
                    key: const Key('download_delete'),
                    onPressed: () => _confirmDelete(context),
                    child: Text(asksForMore(l10n.downloadDeleteButton)),
                  ),
                ],
                child: Semantics(
                  label: '$actionLabel: $name',
                  button: true,
                  excludeSemantics: true,
                  onTap: onAction,
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
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onAction,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

/// The same confirmation for one file or all downloads of a title.
Future<bool> confirmDownloadDeletion(
  BuildContext context,
  List<DownloadItem> items,
  String name, {
  bool all = false,
}) async {
  if (items.isEmpty) return false;
  final l10n = AppLocalizations.of(context);
  final lost = items
      .where((item) => item.status != DownloadStatus.completed)
      .fold<int>(0, (sum, item) => sum + item.downloadedBytes);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(all ? l10n.downloadDeleteAll : l10n.downloadDeleteTitle),
      content: Text(
        [
          all
              ? l10n.downloadDeleteTitleMessage(name)
              : l10n.downloadDeleteMessage(name),
          if (lost > 0)
            l10n.downloadDeleteProgressLost(formatByteSize(l10n, lost)),
        ].join(' '),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.downloadCancelButton),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.downloadDeleteButton),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final cubit = context.read<DownloadManagerCubit>();
  final messenger = ScaffoldMessenger.of(context);
  var deleted = true;
  for (final item in items) {
    if (!await cubit.delete(item.id)) deleted = false;
  }
  if (!deleted && context.mounted) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.downloadDeleteFailed)));
  }
  return deleted;
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
  return [
    facts,
    if (item.quality case final quality?)
      l10n.downloadSelectedQuality(l10n.onlineQualityHeight(quality)),
  ].join(' · ');
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

String _failureMessage(AppLocalizations l10n, DownloadFailure failure) {
  return switch (failure) {
    DownloadFailure.noSpace => l10n.downloadFailedNoSpace,
    DownloadFailure.noAccess => l10n.downloadFailedNoAccess,
    DownloadFailure.fileMissing => l10n.downloadFailedFileMissing,
    DownloadFailure.couldNotStart => l10n.downloadFailedCouldNotStart,
    DownloadFailure.connectionLost => l10n.downloadFailedConnectionLost,
    DownloadFailure.notDownloadable => l10n.downloadFailedNotDownloadable,
    DownloadFailure.other => l10n.downloadFailedMessage,
  };
}

int _byEpisode(DownloadItem left, DownloadItem right) {
  final a = episodeNumberFromFileName(left.fileName);
  final b = episodeNumberFromFileName(right.fileName);
  if (a != null && b != null && a != b) return a.compareTo(b);
  return left.fileName.compareTo(right.fileName);
}
