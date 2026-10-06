import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_line.dart';
import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';
import 'package:iris/features/saved_torrents/presentation/cubit/saved_torrents_cubit.dart';
import 'package:iris/features/saved_torrents/presentation/cubit/saved_torrents_state.dart';
import 'package:iris/features/saved_torrents/presentation/widgets/saved_torrent_dialogs.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/torrent/torrent_key.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
import 'package:iris/shared/utils/file_display_name.dart';

/// Opens a torrent for watching; [autoOpenFileIndex] continues a file.
typedef SavedTorrentWatchCallback =
    void Function(SavedTorrent torrent, {int? autoOpenFileIndex});

class SavedTorrentsView extends StatelessWidget {
  const SavedTorrentsView({
    required this.onAdd,
    required this.onWatch,
    required this.onDownload,
    this.bottomPadding = 0,
    super.key,
  });

  final VoidCallback onAdd;
  final SavedTorrentWatchCallback onWatch;
  final ValueChanged<SavedTorrent> onDownload;

  /// Keeps the last card clear of a floating action button.
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SavedTorrentsCubit, SavedTorrentsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.torrents.isEmpty) {
          return _EmptyState(onAdd: onAdd);
        }
        return _TorrentsGrid(
          state: state,
          onWatch: onWatch,
          onDownload: onDownload,
          bottomPadding: bottomPadding,
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                l10n.savedTorrentsEmptyTitle,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.savedTorrentsEmptyMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_link),
                label: Text(l10n.savedTorrentsAddButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TorrentsGrid extends StatelessWidget {
  const _TorrentsGrid({
    required this.state,
    required this.onWatch,
    required this.onDownload,
    required this.bottomPadding,
  });

  static const _minCardWidth = 420.0;
  static const _spacing = 12.0;

  /// Narrower lists stack the card actions so both labels stay readable.
  static const _minSideBySideActionsWidth = 320.0;

  final SavedTorrentsState state;
  final SavedTorrentWatchCallback onWatch;
  final ValueChanged<SavedTorrent> onDownload;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final latestProgress = {
      for (final progress in latestPerTorrent(context.watchWatchProgress()))
        progress.torrentKey: progress,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = adaptiveColumnCount(
          availableWidth: constraints.maxWidth,
          minItemWidth: _minCardWidth,
          spacing: _spacing,
          maxColumns: 3,
        );
        final torrents = state.torrents;
        final rowCount = (torrents.length / columns).ceil();

        return ListView.separated(
          padding: EdgeInsets.only(bottom: 16 + bottomPadding),
          itemCount: rowCount,
          separatorBuilder: (_, _) => const SizedBox(height: _spacing),
          itemBuilder: (context, index) {
            final start = index * columns;
            final end = math.min(start + columns, torrents.length);
            return AdaptiveGridRow(
              columns: columns,
              spacing: _spacing,
              children: [
                for (final torrent in torrents.sublist(start, end))
                  _buildCard(
                    torrent,
                    latestProgress[torrentKeyFromMagnet(torrent.magnet)],
                    stackActions:
                        constraints.maxWidth < _minSideBySideActionsWidth,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCard(
    SavedTorrent torrent,
    WatchProgress? progress, {
    required bool stackActions,
  }) {
    return _SavedTorrentCard(
      key: ValueKey(torrent.infoHash),
      torrent: torrent,
      progress: progress,
      highlighted: torrent.infoHash == state.highlightedInfoHash,
      stackActions: stackActions,
      // A finished file opens the picker, which offers the next one.
      onWatch: () => onWatch(
        torrent,
        autoOpenFileIndex: progress == null || progress.isFinished
            ? null
            : progress.fileIndex,
      ),
      onDownload: () => onDownload(torrent),
    );
  }
}

class _SavedTorrentCard extends StatelessWidget {
  const _SavedTorrentCard({
    required this.torrent,
    required this.progress,
    required this.highlighted,
    required this.stackActions,
    required this.onWatch,
    required this.onDownload,
    super.key,
  });

  final SavedTorrent torrent;

  /// The torrent's most recently watched file.
  final WatchProgress? progress;
  final bool highlighted;
  final bool stackActions;
  final VoidCallback onWatch;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final date = DateFormat.yMMMd(
      l10n.localeName,
    ).format(torrent.lastUsedAt.toLocal());
    final usedLabel = torrent.lastOpenedAt == null
        ? l10n.savedTorrentsAddedOn(date)
        : l10n.savedTorrentsOpenedOn(date);

    return Card(
      color: highlighted ? theme.colorScheme.secondaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      torrent.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                _CardMenu(torrent: torrent),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                usedLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (progress case final progress?) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.watchProgressLastFile(
                        fileDisplayName(progress.fileName),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    WatchProgressLine(progress: progress),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _CardActions(
                stacked: stackActions,
                continues: progress != null,
                onWatch: onWatch,
                onDownload: onDownload,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MenuAction { rename, copyLink, delete }

class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.torrent});

  final SavedTorrent torrent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_MenuAction>(
      tooltip: l10n.savedTorrentsMoreTooltip,
      onSelected: (action) => _handle(context, action),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _MenuAction.rename,
          child: ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.savedTorrentsRename),
          ),
        ),
        PopupMenuItem(
          value: _MenuAction.copyLink,
          child: ListTile(
            leading: const Icon(Icons.copy),
            title: Text(l10n.savedTorrentsCopyLink),
          ),
        ),
        PopupMenuItem(
          value: _MenuAction.delete,
          child: ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l10n.savedTorrentsDelete),
          ),
        ),
      ],
    );
  }

  Future<void> _handle(BuildContext context, _MenuAction action) async {
    final cubit = context.read<SavedTorrentsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case _MenuAction.rename:
        final title = await showRenameSavedTorrentDialog(
          context: context,
          currentTitle: torrent.title,
        );
        if (title != null) await cubit.rename(torrent.infoHash, title);
      case _MenuAction.copyLink:
        await Clipboard.setData(ClipboardData(text: torrent.magnet));
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.savedTorrentsLinkCopied)),
        );
      case _MenuAction.delete:
        final confirmed = await showDeleteSavedTorrentDialog(
          context: context,
          title: torrent.title,
        );
        if (confirmed) await cubit.delete(torrent.infoHash);
    }
  }
}

/// Streaming is the primary action; downloading is secondary.
class _CardActions extends StatelessWidget {
  const _CardActions({
    required this.stacked,
    required this.continues,
    required this.onWatch,
    required this.onDownload,
  });

  final bool stacked;

  /// The torrent was watched before: the main action continues it.
  final bool continues;
  final VoidCallback onWatch;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final watchButton = FilledButton.icon(
      key: const Key('saved_torrent_watch_button'),
      onPressed: onWatch,
      icon: const Icon(Icons.play_arrow),
      label: Text(
        continues
            ? l10n.watchProgressContinueButton
            : l10n.watchSourcesOpenButton,
      ),
    );
    final downloadButton = FilledButton.tonalIcon(
      key: const Key('saved_torrent_download_button'),
      onPressed: onDownload,
      icon: const Icon(Icons.download),
      label: Text(l10n.downloadsOpenButton),
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [watchButton, const SizedBox(height: 8), downloadButton],
      );
    }
    return Row(
      children: [
        Expanded(child: watchButton),
        const SizedBox(width: 8),
        Expanded(child: downloadButton),
      ],
    );
  }
}
