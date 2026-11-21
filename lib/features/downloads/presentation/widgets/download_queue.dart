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
import 'package:iris/shared/haptics/app_haptics.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/quality_badge.dart';

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
                      _QueueSectionHeading(l10n.downloadQueueCurrent, count: 1),
                      _StatusRow(
                        key: ValueKey(active.id),
                        item: active,
                        onFiles: widget.onFiles,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (failed.isNotEmpty) ...[
                      _QueueSectionHeading(
                        l10n.downloadQueueAttention,
                        count: failed.length,
                        attention: true,
                      ),
                      for (final item in failed)
                        _StatusRow(
                          key: ValueKey(item.id),
                          item: item,
                          onFiles: widget.onFiles,
                        ),
                      const SizedBox(height: 16),
                    ],
                    _QueueSectionHeading(
                      l10n.downloadQueueWaiting,
                      count: waiting.length,
                    ),
                    if (waiting.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
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
                onReorderStart: (_) => AppHaptics.light(),
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
                      const SizedBox(height: 16),
                      _QueueSectionHeading(
                        l10n.downloadQueuePaused,
                        count: paused.length,
                      ),
                      for (final item in paused)
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

class _QueueSectionHeading extends StatelessWidget {
  const _QueueSectionHeading(
    this.title, {
    required this.count,
    this.attention = false,
  });

  final String title;
  final int count;
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: DetailLayout.queueHeadingStyle(
                  theme,
                  color: attention ? theme.colorScheme.error : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$count',
              style: theme.textTheme.labelMedium?.copyWith(
                color: attention
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
      children: [handle, menu],
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
          child: _QueueRow(
            item: item,
            controls: controls,
            focused: _focused,
            footer: item.downloadedBytes > 0
                ? _QueueProgress(item: item)
                : null,
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final number = downloadEpisodeNumber(item);
    final episode = downloadEpisode(l10n, item);
    final title = item.animeTitle.isNotEmpty
        ? item.animeTitle
        : item.sourceTitle.isNotEmpty
        ? item.sourceTitle
        : episode;
    final facts = downloadSourceFacts(item);
    final showSource =
        facts.source.isNotEmpty &&
        facts.source.toLowerCase() != title.toLowerCase();
    return Tooltip(
      message: [
        title,
        item.fileName,
        if (showSource) facts.source,
        if (facts.videoHeight case final height?)
          l10n.onlineQualityHeight(height),
      ].join('\n'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            dimension: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Center(
                  child: number == null
                      ? const PixelIcon(PixelGlyph.file, size: 18)
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            number.toString().padLeft(2, '0'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: item.status == DownloadStatus.failed
                                  ? theme.colorScheme.error
                                  : null,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: DetailLayout.sansFont,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                if (number == null && episode != title) ...[
                  const SizedBox(height: 4),
                  Text(
                    episode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: DetailLayout.sansFont,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (showSource || facts.videoHeight != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showSource)
                        Flexible(
                          child: Text(
                            facts.source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: DetailLayout.monoFont,
                              color: theme.colorScheme.onSurfaceVariant,
                              wordSpacing: -2.0,
                            ),
                          ),
                        ),
                      if (showSource && facts.videoHeight != null)
                        const SizedBox(width: 8),
                      if (facts.videoHeight case final height?)
                        QualityBadge(l10n.onlineQualityHeight(height)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.item,
    required this.controls,
    this.footer,
    this.focused = false,
  });

  final DownloadItem item;
  final Widget controls;
  final Widget? footer;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = item.status == DownloadStatus.failed;
    final actionsBelow = MediaQuery.textScalerOf(context).scale(16) > 23;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AnimatedContainer(
        duration: motionDuration(context, const Duration(milliseconds: 150)),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: failed ? scheme.error.withValues(alpha: 0.07) : null,
          border: Border.all(
            color: focused
                ? scheme.onSurface
                : failed
                ? scheme.error.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ExcludeSemantics(
                      child: _EpisodeIdentity(item: item),
                    ),
                  ),
                  if (!actionsBelow) controls,
                ],
              ),
              if (actionsBelow)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: controls,
                ),
              if (footer case final footer?) ...[
                const SizedBox(height: 12),
                footer,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueProgress extends StatelessWidget {
  const _QueueProgress({required this.item});
  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final active = item.status == DownloadStatus.downloading;
    final knownTotal = item.totalBytes > 0;
    final loaded = formatByteSize(l10n, item.downloadedBytes);
    final total =
        '${item.isOnline ? '~' : ''}${formatByteSize(l10n, item.totalBytes)}';
    final details = knownTotal
        ? l10n.downloadBytesProgress(loaded, total)
        : l10n.downloadBytesDownloaded(loaded);
    final style = theme.textTheme.bodySmall?.copyWith(
      fontFamily: DetailLayout.sansFont,
      color: active ? theme.colorScheme.tertiary : null,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final progress = downloadDisplayProgress(item);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(details, style: style),
              if (active)
                Text(
                  formatTransferRate(l10n, item.downloadRateBytesPerSecond),
                  style: style,
                ),
            ],
          ),
          if (active || knownTotal) ...[
            const SizedBox(height: 8),
            if (knownTotal)
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: progress, end: progress),
                duration: motionDuration(
                  context,
                  const Duration(milliseconds: 240),
                ),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  backgroundColor: DetailLayout.progressTrackColor(
                    theme.colorScheme,
                  ),
                  color: active
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.onSurfaceVariant,
                  semanticsLabel: downloadSemanticName(l10n, item),
                ),
              )
            else
              LinearProgressIndicator(
                value: disableAnimations ? 0.5 : null,
                backgroundColor: DetailLayout.progressTrackColor(
                  theme.colorScheme,
                ),
                color: active
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.onSurfaceVariant,
                semanticsLabel: downloadSemanticName(l10n, item),
              ),
          ],
        ],
      ),
    );
  }
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
    final failed = item.status == DownloadStatus.failed;
    final noSpace = item.failure == DownloadFailure.noSpace;
    final cubit = context.read<DownloadManagerCubit>();
    final l10n = AppLocalizations.of(context);
    final semanticName = downloadSemanticName(l10n, item);
    final deleting = context.select<DownloadManagerCubit, bool>(
      (cubit) => cubit.state.deletingIds.contains(item.id),
    );
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
    final action = Semantics(
      label: '$actionLabel: $semanticName',
      button: true,
      enabled: !deleting,
      excludeSemantics: true,
      onTap: onAction,
      child: IconButton(
        key: ValueKey('queue_pause_${item.id}'),
        tooltip: actionLabel,
        onPressed: onAction,
        icon: DitherSwitcher(
          duration: const Duration(milliseconds: 180),
          child: PixelIcon(
            active
                ? PixelGlyph.pause
                : paused
                ? PixelGlyph.play
                : PixelGlyph.refresh,
            key: ValueKey(item.status),
            size: 18,
          ),
        ),
      ),
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(dimension: 48, child: action),
        RowMenuButton(
          key: ValueKey('queue_menu_${item.id}'),
          controller: _menu,
          tooltip: l10n.commonMoreActions,
          semanticLabel: '$semanticName, ${l10n.commonMoreActions}',
          menuChildren: [
            if (noSpace)
              MenuItemButton(
                key: ValueKey('queue_files_${item.id}'),
                onPressed: widget.onFiles,
                child: Text(l10n.downloadFilesTitle),
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
        ),
      ],
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticName,
      child: _QueueRow(
        item: item,
        controls: controls,
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (active || paused || item.downloadedBytes > 0)
              _QueueProgress(item: item),
            if (failed) ...[
              if (item.downloadedBytes > 0) const SizedBox(height: 12),
              Text(
                downloadFailureMessage(
                  l10n,
                  item.failure ?? DownloadFailure.other,
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
