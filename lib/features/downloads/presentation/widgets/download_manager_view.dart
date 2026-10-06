import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_storage_usage.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_state.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

class DownloadManagerView extends StatelessWidget {
  const DownloadManagerView({required this.onWatch, super.key});

  static const _supportingPaneWidth = 360.0;
  static const _paneGap = 24.0;
  static const _minCardWidth = 420.0;
  static const _cardSpacing = 12.0;

  final ValueChanged<DownloadItem> onWatch;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadManagerCubit, DownloadManagerState>(
      builder: (context, state) {
        if (state.isLoading && state.downloads.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.hasError && state.downloads.isEmpty) {
          return _ManagerFailure(
            onRetry: context.read<DownloadManagerCubit>().load,
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < WindowSizeClass.expandedMinWidth) {
              return _SinglePaneLayout(state: state, onWatch: onWatch);
            }
            return _SupportingPaneLayout(
              state: state,
              onWatch: onWatch,
              columns: adaptiveColumnCount(
                availableWidth:
                    constraints.maxWidth - _supportingPaneWidth - _paneGap,
                minItemWidth: _minCardWidth,
                spacing: _cardSpacing,
                maxColumns: 2,
              ),
            );
          },
        );
      },
    );
  }
}

/// Compact and medium: storage summary on top of the downloads list.
class _SinglePaneLayout extends StatelessWidget {
  const _SinglePaneLayout({required this.state, required this.onWatch});

  final DownloadManagerState state;
  final ValueChanged<DownloadItem> onWatch;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: context.read<DownloadManagerCubit>().refreshStorage,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _StorageCard(usage: state.storageUsage),
          const SizedBox(height: 18),
          if (state.downloads.isEmpty)
            const _EmptyState()
          else
            ..._orderedDownloads(state.downloads).map(
              (item) => Padding(
                padding: const EdgeInsets.only(
                  bottom: DownloadManagerView._cardSpacing,
                ),
                child: _DownloadCard(item: item, onWatch: onWatch),
              ),
            ),
        ],
      ),
    );
  }
}

/// Expanded and wider: downloads in the main pane, storage summary in a
/// supporting pane at the end.
class _SupportingPaneLayout extends StatelessWidget {
  const _SupportingPaneLayout({
    required this.state,
    required this.onWatch,
    required this.columns,
  });

  final DownloadManagerState state;
  final ValueChanged<DownloadItem> onWatch;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final downloads = _orderedDownloads(state.downloads);
    final rowCount = (downloads.length / columns).ceil();
    const spacing = DownloadManagerView._cardSpacing;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: context.read<DownloadManagerCubit>().refreshStorage,
            child: downloads.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [_EmptyState()],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: rowCount,
                    separatorBuilder: (_, _) => const SizedBox(height: spacing),
                    itemBuilder: (context, index) {
                      final start = index * columns;
                      final end = math.min(start + columns, downloads.length);
                      return AdaptiveGridRow(
                        columns: columns,
                        spacing: spacing,
                        children: [
                          for (final item in downloads.sublist(start, end))
                            _DownloadCard(item: item, onWatch: onWatch),
                        ],
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(width: DownloadManagerView._paneGap),
        SizedBox(
          width: DownloadManagerView._supportingPaneWidth,
          child: SingleChildScrollView(
            primary: false,
            padding: const EdgeInsets.only(bottom: 24),
            child: _StorageCard(usage: state.storageUsage),
          ),
        ),
      ],
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.usage});

  final DownloadStorageUsage? usage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.downloadStorageTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _StorageRow(
              label: l10n.downloadStorageTotal,
              value: usage?.totalBytes,
            ),
            const SizedBox(height: 7),
            _StorageRow(
              label: l10n.downloadStorageContent,
              value: usage?.downloadsBytes,
            ),
            const SizedBox(height: 7),
            _StorageRow(
              label: l10n.downloadStorageCache,
              value: usage?.cacheBytes,
              action: (usage?.cacheBytes ?? 0) > 0
                  ? TextButton(
                      key: const Key('download_storage_clear_cache_button'),
                      onPressed: () => _clearCache(context),
                      child: Text(l10n.downloadStorageClearCache),
                    )
                  : null,
            ),
          ],
        ),
      ),
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

class _StorageRow extends StatelessWidget {
  const _StorageRow({required this.label, required this.value, this.action});

  final String label;
  final int? value;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        if (action != null) ...[action!, const SizedBox(width: 4)],
        Text(
          value == null ? '—' : _formatBytes(value!),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({required this.item, required this.onWatch});

  final DownloadItem item;
  final ValueChanged<DownloadItem> onWatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DownloadManagerCubit>();
    final progress = item.totalBytes <= 0
        ? 0.0
        : (item.downloadedBytes / item.totalBytes).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.animeTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: item.status == DownloadStatus.completed ? 1 : progress,
              minHeight: 7,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 12,
              runSpacing: 5,
              children: [
                Text(_statusLabel(l10n, item.status)),
                Text(
                  '${_formatBytes(item.downloadedBytes)} / ${_formatBytes(item.totalBytes)}',
                ),
                if (item.status == DownloadStatus.downloading)
                  Text('${_formatBytes(item.downloadRateBytesPerSecond)}/с'),
                if (item.status == DownloadStatus.downloading)
                  Text(l10n.downloadPeers(item.peers)),
              ],
            ),
            if (item.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.downloadFailedMessage,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.status == DownloadStatus.completed)
                  FilledButton.icon(
                    onPressed: () => onWatch(item),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(l10n.downloadWatchButton),
                  ),
                if (item.status == DownloadStatus.downloading ||
                    item.status == DownloadStatus.queued)
                  OutlinedButton.icon(
                    onPressed: () => cubit.pause(item.id),
                    icon: const Icon(Icons.pause_rounded),
                    label: Text(l10n.downloadPauseButton),
                  ),
                if (item.status == DownloadStatus.paused)
                  OutlinedButton.icon(
                    onPressed: () => cubit.resume(item.id),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(l10n.downloadResumeButton),
                  ),
                if (item.status == DownloadStatus.failed)
                  OutlinedButton.icon(
                    onPressed: () => cubit.retry(item.id),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.commonRetry),
                  ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, item),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(l10n.downloadDeleteButton),
                ),
              ],
            ),
          ],
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
    if (shouldDelete == true && context.mounted) {
      await context.read<DownloadManagerCubit>().delete(item.id);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 20),
      child: Column(
        children: [
          const Icon(Icons.download_done_rounded, size: 52),
          const SizedBox(height: 14),
          Text(
            AppLocalizations.of(context).downloadsEmpty,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ManagerFailure extends StatelessWidget {
  const _ManagerFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 42),
          const SizedBox(height: 12),
          Text(l10n.downloadManagerUnableToLoad),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
        ],
      ),
    );
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

String _formatBytes(int bytes) {
  const units = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}
