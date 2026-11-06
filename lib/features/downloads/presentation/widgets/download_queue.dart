import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_state.dart';
import 'package:iris/features/downloads/presentation/widgets/download_deletion_dialog.dart';
import 'package:iris/features/downloads/presentation/widgets/download_labels.dart';
import 'package:iris/features/downloads/presentation/widgets/download_status_label.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/show_adaptive_sheet.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/row_menu_button.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/tap_row.dart';

class DownloadQueueSummary extends StatelessWidget {
  const DownloadQueueSummary({required this.items, super.key});

  final List<DownloadItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final first = items.first;
    final theme = Theme.of(context);
    return TapRow(
      inkKey: const Key('download_queue_open'),
      onTap: () {
        final cubit = context.read<DownloadManagerCubit>();
        showAdaptiveSheet<void>(
          context: context,
          builder: (_) =>
              BlocProvider.value(value: cubit, child: const _DownloadQueue()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const PixelIcon(PixelGlyph.download, size: 18),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.downloadQueueCount(items.length)),
                  Text(
                    first.animeTitle.isEmpty
                        ? first.sourceTitle
                        : first.animeTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (first.status == DownloadStatus.downloading &&
                first.totalBytes > 0) ...[
              Text('${(first.progress * 100).round()}%'),
              const SizedBox(width: 12),
            ],
            const PixelIcon(PixelGlyph.arrowRight, size: 14),
          ],
        ),
      ),
    );
  }
}

class _DownloadQueue extends StatelessWidget {
  const _DownloadQueue();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        key: const Key('download_queue_sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.downloadQueueTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.pop(context),
                icon: const PixelIcon(PixelGlyph.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: BlocBuilder<DownloadManagerCubit, DownloadManagerState>(
              builder: (context, state) {
                final queue = state.queue;
                final next = queue
                    .where((item) => item.status == DownloadStatus.queued)
                    .firstOrNull;
                if (queue.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      l10n.downloadQueueEmpty,
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: queue.length,
                  separatorBuilder: (_, _) => const SegmentedRule(),
                  itemBuilder: (context, index) {
                    final item = queue[index];
                    final previous = index == 0 ? null : queue[index - 1];
                    final startsGroup =
                        previous == null ||
                        downloadTitleKey(previous) != downloadTitleKey(item) ||
                        downloadSourceKey(previous.magnet) !=
                            downloadSourceKey(item.magnet);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (startsGroup)
                          Padding(
                            padding: EdgeInsets.only(
                              top: index == 0 ? 0 : 16,
                              bottom: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.animeTitle.isNotEmpty)
                                  Text(
                                    item.animeTitle,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                Text(
                                  downloadSourceLabel(l10n, item),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        _QueueRow(
                          key: ValueKey(queue[index].id),
                          item: queue[index],
                          canPrioritize:
                              queue[index].status == DownloadStatus.queued &&
                              queue[index].id != next?.id,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatefulWidget {
  const _QueueRow({required this.item, required this.canPrioritize, super.key});

  final DownloadItem item;
  final bool canPrioritize;

  @override
  State<_QueueRow> createState() => _QueueRowState();
}

class _QueueRowState extends State<_QueueRow> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DownloadManagerCubit>();
    final status =
        item.status == DownloadStatus.downloading && item.totalBytes > 0
        ? '${(item.progress * 100).round()}%'
        : downloadStatusLabel(l10n, item.status);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        downloadEpisode(l10n, item),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(status),
      onLongPress: _menu.open,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ValueKey('queue_pause_${item.id}'),
            tooltip: l10n.downloadPauseButton,
            onPressed: () => cubit.pause(item.id),
            icon: const PixelIcon(PixelGlyph.pause, size: 18),
          ),
          RowMenuButton(
            key: ValueKey('queue_menu_${item.id}'),
            controller: _menu,
            tooltip: l10n.commonMoreActions,
            semanticLabel:
                '${downloadName(l10n, item)}, ${l10n.commonMoreActions}',
            menuChildren: [
              if (widget.canPrioritize)
                MenuItemButton(
                  key: ValueKey('queue_next_${item.id}'),
                  onPressed: () => cubit.downloadNext(item.id),
                  child: Text(l10n.downloadNext),
                ),
              MenuItemButton(
                key: ValueKey('queue_delete_${item.id}'),
                onPressed: () => confirmDownloadDeletion(context, [
                  item,
                ], downloadName(l10n, item)),
                child: Text(l10n.downloadDeleteButton),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
