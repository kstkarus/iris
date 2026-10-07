import 'package:flutter/foundation.dart';
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
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// Opens a torrent for watching; [autoOpenFileIndex] continues a file.
typedef SavedTorrentWatchCallback =
    void Function(SavedTorrent torrent, {int? autoOpenFileIndex});

/// The saved torrents as rows under one "add" action; with nothing saved
/// the page is just the invitation to add, so the action is never shown
/// twice.
class SavedTorrentsView extends StatelessWidget {
  const SavedTorrentsView({
    required this.onAdd,
    required this.onWatch,
    required this.onDownload,
    required this.addButtonKey,
    super.key,
  });

  final VoidCallback onAdd;
  final SavedTorrentWatchCallback onWatch;
  final ValueChanged<SavedTorrent> onDownload;
  final Key addButtonKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<SavedTorrentsCubit, SavedTorrentsState>(
      builder: (context, state) {
        if (state.isLoading) return const LoadingView();
        final addButton = FilledButton(
          key: addButtonKey,
          onPressed: onAdd,
          child: Text(l10n.savedTorrentsAddButton),
        );
        if (state.torrents.isEmpty) {
          return MessageView(
            title: l10n.savedTorrentsEmptyTitle,
            message: l10n.savedTorrentsEmptyMessage,
            action: addButton,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(addButton: addButton),
            const SizedBox(height: 16),
            Expanded(
              child: _TorrentList(
                state: state,
                onWatch: onWatch,
                onDownload: onDownload,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The add action, with the keyboard shortcut spelled out where there is
/// a keyboard.
class _Header extends StatelessWidget {
  const _Header({required this.addButton});

  final Widget addButton;

  @override
  Widget build(BuildContext context) {
    final hasKeyboard = switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => true,
      _ => false,
    };
    return Row(
      children: [
        Expanded(
          child: hasKeyboard
              ? Text(
                  AppLocalizations.of(context).savedTorrentsPasteHint,
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 16),
        addButton,
      ],
    );
  }
}

class _TorrentList extends StatelessWidget {
  const _TorrentList({
    required this.state,
    required this.onWatch,
    required this.onDownload,
  });

  final SavedTorrentsState state;
  final SavedTorrentWatchCallback onWatch;
  final ValueChanged<SavedTorrent> onDownload;

  @override
  Widget build(BuildContext context) {
    final latestProgress = {
      for (final progress in latestPerTorrent(context.watchWatchProgress()))
        progress.torrentKey: progress,
    };
    final torrents = state.torrents;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= WindowSizeClass.mediumMinWidth;
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: torrents.length + 1,
          separatorBuilder: (_, _) => const SegmentedRule(),
          itemBuilder: (context, index) {
            // A rule above the first row as well as between rows.
            if (index == 0) return const SizedBox.shrink();
            final torrent = torrents[index - 1];
            final progress =
                latestProgress[torrentKeyFromMagnet(torrent.magnet)];
            return _TorrentRow(
              key: ValueKey(torrent.infoHash),
              torrent: torrent,
              progress: progress,
              highlighted: torrent.infoHash == state.highlightedInfoHash,
              wide: wide,
              // A finished file opens the picker, which offers the next one.
              onWatch: () => onWatch(
                torrent,
                autoOpenFileIndex: progress == null || progress.isFinished
                    ? null
                    : progress.fileIndex,
              ),
              onDownload: () => onDownload(torrent),
            );
          },
        );
      },
    );
  }
}

/// One saved torrent. The row itself watches (or continues) it; download
/// and the menu sit at its end.
class _TorrentRow extends StatelessWidget {
  const _TorrentRow({
    required this.torrent,
    required this.progress,
    required this.highlighted,
    required this.wide,
    required this.onWatch,
    required this.onDownload,
    super.key,
  });

  final SavedTorrent torrent;

  /// The torrent's most recently watched file.
  final WatchProgress? progress;
  final bool highlighted;

  /// Wide rows end in an arrow, like the catalog's rows; narrow ones
  /// leave the width to the title.
  final bool wide;
  final VoidCallback onWatch;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final progress = this.progress;
    final date = DateFormat.yMMMd(
      l10n.localeName,
    ).format(torrent.lastUsedAt.toLocal());
    final usedLabel = torrent.lastOpenedAt == null
        ? l10n.savedTorrentsAddedOn(date)
        : l10n.savedTorrentsOpenedOn(date);

    return Material(
      color: highlighted
          ? theme.colorScheme.surfaceContainer
          : Colors.transparent,
      child: InkWell(
        key: const Key('saved_torrent_watch_button'),
        onTap: onWatch,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 0, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      torrent.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        usedLabel,
                        if (progress != null)
                          l10n.watchProgressLastFile(
                            fileDisplayName(progress.fileName),
                          ),
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 10),
                      WatchProgressLine(progress: progress),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                key: const Key('saved_torrent_download_button'),
                tooltip: l10n.downloadsOpenButton,
                icon: const PixelIcon(PixelGlyph.download, size: 18),
                onPressed: onDownload,
              ),
              _RowMenu(torrent: torrent),
              if (wide)
                const Padding(
                  padding: EdgeInsets.only(left: 4, right: 8),
                  child: PixelIcon(PixelGlyph.arrowRight, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MenuAction { rename, copyLink, delete }

class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.torrent});

  final SavedTorrent torrent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_MenuAction>(
      tooltip: l10n.savedTorrentsMoreTooltip,
      icon: const PixelIcon(PixelGlyph.more, size: 18),
      onSelected: (action) => _handle(context, action),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _MenuAction.rename,
          child: Text(l10n.savedTorrentsRename),
        ),
        PopupMenuItem(
          value: _MenuAction.copyLink,
          child: Text(l10n.savedTorrentsCopyLink),
        ),
        PopupMenuItem(
          value: _MenuAction.delete,
          child: Text(l10n.savedTorrentsDelete),
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
