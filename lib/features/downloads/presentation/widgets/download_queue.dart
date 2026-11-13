import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iris/features/downloads/domain/entities/download_failure.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_state.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/section_label.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

import 'package:iris/features/downloads/presentation/widgets/download_labels.dart';
import 'package:iris/features/downloads/presentation/widgets/download_deletion_dialog.dart';
import 'package:iris/features/downloads/presentation/widgets/download_status_label.dart';
import 'package:iris/shared/widgets/row_menu_button.dart';

class DownloadQueueView extends StatefulWidget {
  const DownloadQueueView({required this.onFiles, super.key});
  final VoidCallback onFiles;

  @override
  State<DownloadQueueView> createState() => _DownloadQueueViewState();
}

class _DownloadQueueViewState extends State<DownloadQueueView> {
  List<String> get _waitingIds => context
      .read<DownloadManagerCubit>()
      .state
      .queue
      .where((item) => item.status == DownloadStatus.queued)
      .map((item) => item.id)
      .toList();

  Future<void> _reorder(List<String> order) async {
    final cubit = context.read<DownloadManagerCubit>();
    final before = _waitingIds;
    final changed = await cubit.reorderQueue(order);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          changed ? l10n.downloadQueueChanged : l10n.downloadQueueReorderFailed,
        ),
        action: changed
            ? SnackBarAction(
                label: l10n.commonUndo,
                onPressed: () async {
                  final restored = await cubit.reorderQueue(before);
                  if (!restored && mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.downloadQueueReorderFailed)),
                    );
                  }
                },
              )
            : null,
      ),
    );
  }

  void _move(String id, int to) {
    final ids = _waitingIds;
    if (!ids.remove(id)) return;
    ids.insert(to.clamp(0, ids.length), id);
    _reorder(ids);
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<DownloadManagerCubit, DownloadManagerState>(
    builder: (context, state) {
      final l10n = AppLocalizations.of(context);
      final active = state.downloads
          .where((item) => item.status == DownloadStatus.downloading)
          .firstOrNull;
      final waiting = state.downloads
          .where((item) => item.status == DownloadStatus.queued)
          .toList();
      final paused = state.downloads
          .where((item) => item.status == DownloadStatus.paused)
          .toList();
      final failed = state.downloads
          .where((item) => item.status == DownloadStatus.failed)
          .toList();
      final membership =
          waiting
              .where((item) => !state.deletingIds.contains(item.id))
              .map((item) => item.id)
              .toList()
            ..sort();
      return Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: CustomScrollView(
            key: const Key('queue_scroll'),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (active != null) ...[
                      SectionLabel(l10n.downloadQueueCurrent),
                      const SizedBox(height: 12),
                      _StatusRow(
                        key: ValueKey(active.id),
                        item: active,
                        onFiles: widget.onFiles,
                      ),
                      const SizedBox(height: 28),
                    ],
                    SectionLabel(
                      '${l10n.downloadQueueWaiting} · ${waiting.length}',
                    ),
                    const SizedBox(height: 8),
                    if (waiting.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          active == null && paused.isEmpty && failed.isEmpty
                              ? l10n.downloadQueueFinished
                              : l10n.downloadQueueNoWaiting,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                  ],
                ),
              ),
              SliverReorderableList(
                // A changed membership cancels a drag before an obsolete index can be applied.
                key: ValueKey('queue_waiting_${membership.join(',')}'),
                itemCount: waiting.length,
                onReorderItem: (from, to) {
                  final ids = waiting.map((item) => item.id).toList();
                  if (from < 0 || from >= ids.length) return;
                  final id = ids.removeAt(from);
                  ids.insert(to.clamp(0, ids.length), id);
                  _reorder(ids);
                },
                // The drag overlay is outside the route's providers.
                proxyDecorator: (child, index, animation) => BlocProvider.value(
                  value: context.read<DownloadManagerCubit>(),
                  child: Material(
                    key: const Key('queue_drag_feedback'),
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      child: child,
                    ),
                  ),
                ),
                itemBuilder: (context, index) => _WaitingRow(
                  key: ValueKey(waiting[index].id),
                  item: waiting[index],
                  index: index,
                  count: waiting.length,
                  onMove: (position) => _move(waiting[index].id, position),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (paused.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      SectionLabel(
                        '${l10n.downloadQueuePaused} · ${paused.length}',
                      ),
                      for (final item in paused)
                        _StatusRow(
                          key: ValueKey(item.id),
                          item: item,
                          onFiles: widget.onFiles,
                        ),
                    ],
                    if (failed.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      SectionLabel(
                        '${l10n.downloadQueueAttention} · ${failed.length}',
                      ),
                      for (final item in failed)
                        _StatusRow(
                          key: ValueKey(item.id),
                          item: item,
                          onFiles: widget.onFiles,
                        ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _WaitingRow extends StatefulWidget {
  const _WaitingRow({
    required this.item,
    required this.index,
    required this.count,
    required this.onMove,
    super.key,
  });
  final DownloadItem item;
  final int index;
  final int count;
  final ValueChanged<int> onMove;

  @override
  State<_WaitingRow> createState() => _WaitingRowState();
}

class _WaitingRowState extends State<_WaitingRow> {
  bool _focused = false;
  final _menuFocus = FocusNode();
  final _menu = MenuController();

  @override
  void dispose() {
    _menuFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DownloadManagerCubit>();
    final deleting = context.select<DownloadManagerCubit, bool>(
      (cubit) => cubit.state.deletingIds.contains(widget.item.id),
    );
    final item = widget.item;
    final semanticName = downloadSemanticName(l10n, item);
    final index = widget.index;
    final first = index == 0 || deleting;
    final last = index == widget.count - 1 || deleting;
    final scheme = Theme.of(context).colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 23;
    final actions = <CustomSemanticsAction, VoidCallback>{
      if (!first)
        CustomSemanticsAction(label: l10n.downloadQueueMoveUp): () =>
            widget.onMove(index - 1),
      if (!last)
        CustomSemanticsAction(label: l10n.downloadQueueMoveDown): () =>
            widget.onMove(index + 1),
    };
    final bindings = <ShortcutActivator, VoidCallback>{
      if (!first)
        const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): () =>
            widget.onMove(index - 1),
      if (!last)
        const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): () =>
            widget.onMove(index + 1),
    };
    final menu = RowMenuButton(
      key: ValueKey('queue_menu_${item.id}'),
      controller: _menu,
      focusNode: _menuFocus,
      tooltip: l10n.commonMoreActions,
      semanticLabel: '$semanticName, ${l10n.commonMoreActions}',
      menuChildren: [
        MenuItemButton(
          onPressed: first ? null : () => widget.onMove(0),
          key: ValueKey('queue_next_${item.id}'),
          child: Text(l10n.downloadNext),
        ),
        MenuItemButton(
          onPressed: first ? null : () => widget.onMove(index - 1),
          child: Text(l10n.downloadQueueMoveUp),
        ),
        MenuItemButton(
          onPressed: last ? null : () => widget.onMove(index + 1),
          child: Text(l10n.downloadQueueMoveDown),
        ),
        MenuItemButton(
          key: ValueKey('queue_pause_${item.id}'),
          onPressed: deleting ? null : () => cubit.pause(item.id),
          child: Text(l10n.downloadPauseButton),
        ),
        MenuItemButton(
          key: ValueKey('queue_delete_${item.id}'),
          onPressed: deleting
              ? null
              : () => confirmDownloadDeletion(context, [
                  item,
                ], downloadName(l10n, item)),
          child: Text(l10n.downloadDeleteButton),
        ),
      ],
    );
    final handle = ReorderableDragStartListener(
      index: index,
      enabled: !deleting,
      key: ValueKey('queue_handle_${item.id}'),
      child: Tooltip(
        message: '${l10n.downloadQueueMove}: ${downloadName(l10n, item)}',
        excludeFromSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 18,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var line = 0; line < 3; line++)
                      SizedBox(
                        width: 16,
                        height: 2,
                        child: ColoredBox(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [menu, handle],
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '${index + 1}. $semanticName',
      customSemanticsActions: actions,
      child: CallbackShortcuts(
        bindings: bindings,
        child: Focus(
          key: ValueKey('queue_focus_${item.id}'),
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: _focused ? scheme.onSurface : Colors.transparent,
              ),
            ),
            child: Column(
              children: [
                if (index > 0) const SegmentedRule(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: ExcludeSemantics(
                              child: Text(
                                '${index + 1}',
                                key: ValueKey('queue_position_${item.id}'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ExcludeSemantics(
                              child: _EpisodeIdentity(item: item),
                            ),
                          ),
                          if (!largeText) controls,
                        ],
                      ),
                      if (largeText)
                        Align(
                          alignment: Alignment.centerRight,
                          child: controls,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeIdentity extends StatelessWidget {
  const _EpisodeIdentity({required this.item});
  final DownloadItem item;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: [
      if (item.animeTitle.isNotEmpty)
        item.animeTitle
      else if (item.sourceTitle.isNotEmpty)
        item.sourceTitle,
      item.fileName,
    ].join('\n'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.animeTitle.isEmpty ? item.sourceTitle : item.animeTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          '${downloadEpisode(AppLocalizations.of(context), item)} · ${downloadSourceLabel(AppLocalizations.of(context), item)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _StatusRow extends StatefulWidget {
  const _StatusRow({required this.item, required this.onFiles, super.key});
  final DownloadItem item;
  final VoidCallback onFiles;

  @override
  State<_StatusRow> createState() => _StatusRowState();
}

class _StatusRowState extends State<_StatusRow> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final active = item.status == DownloadStatus.downloading;
    final paused = item.status == DownloadStatus.paused;
    final noSpace = item.failure == DownloadFailure.noSpace;
    final cubit = context.read<DownloadManagerCubit>();
    final l10n = AppLocalizations.of(context);
    final semanticName = downloadSemanticName(l10n, item);
    final deleting = context.select<DownloadManagerCubit, bool>(
      (cubit) => cubit.state.deletingIds.contains(item.id),
    );
    final status = active
        ? '${item.totalBytes > 0 ? '${(item.progress * 100).round()}% · ' : ''}${formatTransferRate(l10n, item.downloadRateBytesPerSecond)}'
        : paused
        ? formatByteSize(l10n, item.downloadedBytes)
        : downloadFailureMessage(l10n, item.failure ?? DownloadFailure.other);
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 23;
    final actionLabel = active
        ? l10n.downloadPauseButton
        : paused
        ? l10n.downloadResumeButton
        : l10n.commonRetry;
    final onAction = deleting
        ? null
        : active
        ? () => cubit.pause(item.id)
        : paused
        ? () => cubit.resume(item.id)
        : () => cubit.retry(item.id);
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '$actionLabel: $semanticName',
          button: true,
          enabled: !deleting,
          excludeSemantics: true,
          onTap: onAction,
          child: IconButton(
            key: ValueKey('queue_pause_${item.id}'),
            tooltip: actionLabel,
            onPressed: onAction,
            icon: PixelIcon(
              active ? PixelGlyph.pause : PixelGlyph.download,
              size: 18,
            ),
          ),
        ),
        RowMenuButton(
          key: ValueKey('queue_menu_${item.id}'),
          controller: _menu,
          tooltip: l10n.commonMoreActions,
          semanticLabel: '$semanticName, ${l10n.commonMoreActions}',
          menuChildren: [
            MenuItemButton(
              key: ValueKey('queue_delete_${item.id}'),
              onPressed: deleting
                  ? null
                  : () => confirmDownloadDeletion(context, [
                      item,
                    ], downloadName(l10n, item)),
              child: Text(l10n.downloadDeleteButton),
            ),
          ],
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: semanticName,
                  child: ExcludeSemantics(child: _EpisodeIdentity(item: item)),
                ),
              ),
              if (!largeText) controls,
            ],
          ),
          if (largeText)
            Align(alignment: Alignment.centerRight, child: controls),
          const SizedBox(height: 12),
          if (active) ...[
            LinearProgressIndicator(
              value: item.totalBytes > 0 ? item.progress : null,
              color: Theme.of(context).colorScheme.tertiary,
              semanticsLabel: semanticName,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            status,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: active
                  ? Theme.of(context).colorScheme.tertiary
                  : paused
                  ? null
                  : Theme.of(context).colorScheme.error,
            ),
          ),
          if (noSpace)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('free_space'),
                onPressed: widget.onFiles,
                child: Text(l10n.downloadFilesTitle),
              ),
            ),
        ],
      ),
    );
  }
}
