import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_storage_usage.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_state.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/section_label.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/spec_table.dart';
import 'package:iris/shared/widgets/status_views.dart';

class DownloadManagerView extends StatelessWidget {
  const DownloadManagerView({required this.onWatch, super.key});

  static const _storagePaneWidth = 360.0;
  static const _paneGap = 40.0;

  final ValueChanged<DownloadItem> onWatch;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadManagerCubit, DownloadManagerState>(
      builder: (context, state) {
        if (state.isLoading && state.downloads.isEmpty) {
          return const LoadingView();
        }
        if (state.hasError && state.downloads.isEmpty) {
          final l10n = AppLocalizations.of(context);
          return MessageView(
            message: l10n.downloadManagerUnableToLoad,
            action: FilledButton(
              onPressed: context.read<DownloadManagerCubit>().load,
              child: Text(l10n.commonRetry),
            ),
          );
        }
        final refresh = context.read<DownloadManagerCubit>().refreshStorage;
        return LayoutBuilder(
          builder: (context, constraints) {
            final storage = _Storage(usage: state.storageUsage);
            final downloads = _orderedDownloads(state.downloads);
            if (constraints.maxWidth < WindowSizeClass.expandedMinWidth) {
              return RefreshIndicator(
                onRefresh: refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  // The files come first: they are what the page is for.
                  children: [
                    _Downloads(downloads: downloads, onWatch: onWatch),
                    const SizedBox(height: 40),
                    storage,
                  ],
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
                      children: [
                        _Downloads(downloads: downloads, onWatch: onWatch),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: _paneGap),
                SizedBox(
                  width: _storagePaneWidth,
                  child: SingleChildScrollView(primary: false, child: storage),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Storage extends StatelessWidget {
  const _Storage({required this.usage});

  final DownloadStorageUsage? usage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
  const _Downloads({required this.downloads, required this.onWatch});

  final List<DownloadItem> downloads;
  final ValueChanged<DownloadItem> onWatch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.downloadsFilesTitle),
        const SizedBox(height: 8),
        if (downloads.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text(
              l10n.downloadsEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final (index, item) in downloads.indexed) ...[
            if (index > 0) const SegmentedRule(),
            _DownloadRow(item: item, onWatch: onWatch),
          ],
      ],
    );
  }
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({required this.item, required this.onWatch});

  final DownloadItem item;
  final ValueChanged<DownloadItem> onWatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DownloadManagerCubit>();
    final status = item.status;
    final completed = status == DownloadStatus.completed;
    final progress = item.totalBytes <= 0
        ? 0.0
        : (item.downloadedBytes / item.totalBytes).clamp(0.0, 1.0);
    final facts = [
      if (completed)
        formatByteSize(l10n, item.totalBytes)
      else
        '${formatByteSize(l10n, item.downloadedBytes)} / '
            '${formatByteSize(l10n, item.totalBytes)}',
      if (status == DownloadStatus.downloading) ...[
        l10n.playerRate(formatByteSize(l10n, item.downloadRateBytesPerSecond)),
        l10n.downloadPeers(item.peers),
      ],
    ].join(' · ');

    final (actionIcon, actionLabel, onAction) = switch (status) {
      DownloadStatus.completed => (
        PixelGlyph.play,
        l10n.downloadWatchButton,
        () => onWatch(item),
      ),
      DownloadStatus.downloading || DownloadStatus.queued => (
        PixelGlyph.pause,
        l10n.downloadPauseButton,
        () => cubit.pause(item.id),
      ),
      DownloadStatus.paused => (
        PixelGlyph.play,
        l10n.downloadResumeButton,
        () => cubit.resume(item.id),
      ),
      DownloadStatus.failed => (
        PixelGlyph.refresh,
        l10n.commonRetry,
        () => cubit.retry(item.id),
      ),
    };

    return Material(
      // Ink paints on the nearest Material: this one scrolls with the row,
      // so the list's edge clips the highlight.
      type: MaterialType.transparency,
      child: InkWell(
        onTap: completed ? () => onWatch(item) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 0, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.animeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileDisplayName(item.fileName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (!completed) ...[
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
                            text: _statusLabel(l10n, status).toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: switch (status) {
                                DownloadStatus.downloading => scheme.tertiary,
                                DownloadStatus.failed => scheme.error,
                                _ => scheme.onSurface,
                              },
                            ),
                          ),
                          TextSpan(text: '   $facts'),
                        ],
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (item.errorMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.downloadFailedMessage,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: actionLabel,
                icon: PixelIcon(actionIcon, size: 18),
                onPressed: onAction,
              ),
              IconButton(
                tooltip: l10n.downloadDeleteButton,
                icon: const PixelIcon(PixelGlyph.delete, size: 18),
                onPressed: () => _confirmDelete(context, item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, DownloadItem item) async {
    final l10n = AppLocalizations.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.downloadDeleteTitle),
        content: Text(l10n.downloadDeleteMessage(item.fileName)),
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

String _statusLabel(AppLocalizations l10n, DownloadStatus status) {
  return switch (status) {
    DownloadStatus.queued => l10n.downloadStatusQueued,
    DownloadStatus.downloading => l10n.downloadStatusDownloading,
    DownloadStatus.paused => l10n.downloadStatusPaused,
    DownloadStatus.completed => l10n.downloadStatusCompleted,
    DownloadStatus.failed => l10n.downloadStatusFailed,
  };
}

List<DownloadItem> _orderedDownloads(List<DownloadItem> downloads) {
  final result = List<DownloadItem>.of(downloads);
  result.sort((left, right) {
    final statusComparison = _statusPriority(
      left.status,
    ).compareTo(_statusPriority(right.status));
    if (statusComparison != 0) return statusComparison;
    return right.createdAt.compareTo(left.createdAt);
  });
  return result;
}

int _statusPriority(DownloadStatus status) {
  return switch (status) {
    DownloadStatus.downloading => 0,
    DownloadStatus.queued => 1,
    DownloadStatus.paused => 2,
    DownloadStatus.failed => 3,
    DownloadStatus.completed => 4,
  };
}
