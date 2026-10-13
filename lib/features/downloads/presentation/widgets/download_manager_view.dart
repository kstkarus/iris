import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_failure.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_storage_usage.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_state.dart';
import 'package:iris/features/downloads/presentation/widgets/download_status_label.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/desktop_platform.dart';
import 'package:iris/shared/utils/episode_number.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/focusable_list_row.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/row_menu_button.dart';
import 'package:iris/shared/widgets/section_label.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/spec_table.dart';
import 'package:iris/shared/widgets/status_views.dart';

class DownloadManagerView extends StatefulWidget {
  const DownloadManagerView({
    required this.onWatch,
    required this.onBrowseCatalog,
    super.key,
  });

  static const _storagePaneWidth = 360.0;
  static const _paneGap = 40.0;

  final ValueChanged<DownloadItem> onWatch;

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
        final refresh = context.read<DownloadManagerCubit>().refreshStorage;
        return LayoutBuilder(
          builder: (context, constraints) {
            final storage = _Storage(usage: state.storageUsage);
            final files = _Downloads(
              downloads: orderedDownloads(state.downloads),
              onWatch: widget.onWatch,
              onBrowseCatalog: widget.onBrowseCatalog,
            );
            if (constraints.maxWidth < WindowSizeClass.expandedMinWidth) {
              return RefreshIndicator(
                onRefresh: refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  // The files come first: they are what the page is for.
                  children: [files, const SizedBox(height: 40), storage],
                ),
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [files],
                    ),
                  ),
                ),
                const SizedBox(width: DownloadManagerView._paneGap),
                SizedBox(
                  width: DownloadManagerView._storagePaneWidth,
                  child: SingleChildScrollView(primary: false, child: storage),
                ),
              ],
            );
          },
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
      : l10n.playerEpisodeNumber(number);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.downloadStorageTitle),
        const SizedBox(height: 12),
        SpecTable(
          labelWidth: 196,
          rows: [
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
          ],
        ),
        const SizedBox(height: 8),
        // What the cache is and what clearing it costs.
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

class _Downloads extends StatelessWidget {
  const _Downloads({
    required this.downloads,
    required this.onWatch,
    required this.onBrowseCatalog,
  });

  static const browseCatalogKey = Key('downloads_browse_catalog');

  final List<DownloadItem> downloads;
  final ValueChanged<DownloadItem> onWatch;
  final VoidCallback onBrowseCatalog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.downloadsFilesTitle),
        const SizedBox(height: 8),
        if (downloads.isEmpty)
          // Where a download starts, and the way there.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Text(
                  l10n.downloadsEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  key: browseCatalogKey,
                  onPressed: onBrowseCatalog,
                  child: Text(l10n.commonBrowseCatalog),
                ),
              ],
            ),
          )
        else
          for (final (index, item) in downloads.indexed) ...[
            if (index > 0) const SegmentedRule(),
            _DownloadRow(key: ValueKey(item.id), item: item, onWatch: onWatch),
          ],
      ],
    );
  }
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
    final summary = [
      name,
      statusLabel,
      if (!completed && item.totalBytes > 0) '${(progress * 100).round()} %',
      if (failure != null) _failureMessage(l10n, failure),
    ].join(', ');

    return FocusableListRow(
      onDelete: () => _confirmDelete(context),
      filled: _menuOpen,
      onTap: completed ? () => widget.onWatch(item) : null,
      onLongPress: _menu.open,
      onSecondaryTap: _menu.open,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 0, 14),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                container: true,
                label: summary,
                child: ExcludeSemantics(
                  child: _Details(
                    item: item,
                    progress: progress,
                    statusLabel: statusLabel,
                    failure: failure,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: '$actionLabel: $name',
              button: true,
              excludeSemantics: true,
              onTap: onAction,
              child: IconButton(
                tooltip: actionLabel,
                icon: PixelIcon(actionIcon, size: 18),
                onPressed: onAction,
              ),
            ),
            RowMenuButton(
              controller: _menu,
              tooltip: l10n.commonMoreActions,
              semanticLabel: '${l10n.commonMoreActions}: $name',
              onOpenChanged: _setMenuOpen,
              menuChildren: [
                MenuItemButton(onPressed: onAction, child: Text(actionLabel)),
                // Apart, so it is not hit on the way to the rest.
                const Divider(height: 1),
                MenuItemButton(
                  key: const Key('download_delete'),
                  onPressed: () => _confirmDelete(context),
                  child: Text(asksForMore(l10n.downloadDeleteButton)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Asks first: a file is costly to download again, unlike a saved link.
  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final item = widget.item;
    final lost =
        item.status != DownloadStatus.completed && item.downloadedBytes > 0;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.downloadDeleteTitle),
        content: Text(
          [
            l10n.downloadDeleteMessage(downloadName(l10n, item)),
            if (lost)
              l10n.downloadDeleteProgressLost(
                formatByteSize(l10n, item.downloadedBytes),
              ),
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
    if (shouldDelete != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await context.read<DownloadManagerCubit>().delete(item.id);
    if (!deleted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.downloadDeleteFailed)),
      );
    }
  }
}

/// The title, the episode, the bar of an unfinished file and how it goes.
class _Details extends StatelessWidget {
  const _Details({
    required this.item,
    required this.progress,
    required this.statusLabel,
    required this.failure,
  });

  final DownloadItem item;
  final double progress;
  final String statusLabel;
  final DownloadFailure? failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final status = item.status;
    final failure = this.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.animeTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 2),
        Text(
          downloadEpisode(l10n, item),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        if (status != DownloadStatus.completed) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SegmentedBar(
              value: progress,
              color: switch (status) {
                DownloadStatus.downloading => scheme.tertiary,
                DownloadStatus.failed => scheme.error,
                _ => scheme.onSurfaceVariant,
              },
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: statusLabel.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: switch (status) {
                    DownloadStatus.downloading => scheme.tertiary,
                    DownloadStatus.failed => scheme.error,
                    _ => scheme.onSurface,
                  },
                ),
              ),
              TextSpan(text: '   ${_facts(l10n, item)}'),
            ],
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (failure != null) ...[
          const SizedBox(height: 4),
          Text(
            _failureMessage(l10n, failure),
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
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
  return switch (item.status) {
    DownloadStatus.completed => total ?? '',
    // Nothing of it is here yet: only how big it will be.
    DownloadStatus.queued when item.downloadedBytes == 0 => total ?? '',
    DownloadStatus.downloading => [
      loaded.join(' / '),
      if (item.peers == 0 && !item.isOnline)
        l10n.downloadNoPeers
      else ...[
        ?_timeLeft(l10n, item),
        formatTransferRate(l10n, item.downloadRateBytesPerSecond),
      ],
    ].join(' · '),
    _ => loaded.join(' / '),
  };
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

/// Active files first, by status; within a status, one title's files
/// stay together in episode order, the title with the newest file first.
@visibleForTesting
List<DownloadItem> orderedDownloads(List<DownloadItem> downloads) {
  final result = <DownloadItem>[];
  for (final status in _statusOrder) {
    final groups = <String, List<DownloadItem>>{};
    for (final item in downloads.where((item) => item.status == status)) {
      groups.putIfAbsent(item.animeTitle, () => []).add(item);
    }
    DateTime newest(List<DownloadItem> group) => group
        .map((item) => item.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final ordered = groups.values.toList()
      ..sort((left, right) => newest(right).compareTo(newest(left)));
    for (final group in ordered) {
      group.sort(_byEpisode);
      result.addAll(group);
    }
  }
  return result;
}

const _statusOrder = [
  DownloadStatus.downloading,
  DownloadStatus.queued,
  DownloadStatus.paused,
  DownloadStatus.failed,
  DownloadStatus.completed,
];

int _byEpisode(DownloadItem left, DownloadItem right) {
  final a = episodeNumberFromFileName(left.fileName);
  final b = episodeNumberFromFileName(right.fileName);
  if (a != null && b != null && a != b) return a.compareTo(b);
  return left.fileName.compareTo(right.fileName);
}
