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
import 'package:iris/shared/utils/desktop_platform.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/utils/episode_number.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/row_menu_button.dart';
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
        if (state.isLoading) {
          return LoadingView(semanticsLabel: l10n.savedTorrentsLoading);
        }
        final addButton = FilledButton(
          key: addButtonKey,
          onPressed: onAdd,
          child: Text(l10n.savedTorrentsAddButton),
        );
        final pasteHint = _pasteHint(context);
        if (state.torrents.isEmpty) {
          return MessageView(
            title: l10n.savedTorrentsEmptyTitle,
            message: l10n.savedTorrentsEmptyMessage,
            action: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                addButton,
                if (pasteHint != null) ...[
                  const SizedBox(height: 16),
                  Text(pasteHint, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(addButton: addButton, pasteHint: pasteHint),
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

/// The paste shortcut in the platform's own spelling, where there is a
/// keyboard; null on phones.
String? _pasteHint(BuildContext context) {
  final shortcut = switch (defaultTargetPlatform) {
    TargetPlatform.macOS => '⌘V',
    TargetPlatform.windows || TargetPlatform.linux => 'Ctrl+V',
    _ => null,
  };
  if (shortcut == null) return null;
  return AppLocalizations.of(context).savedTorrentsPasteHint(shortcut);
}

/// The add action, with the paste shortcut beside it where there is one.
class _Header extends StatelessWidget {
  const _Header({required this.addButton, required this.pasteHint});

  final Widget addButton;
  final String? pasteHint;

  @override
  Widget build(BuildContext context) {
    final pasteHint = this.pasteHint;
    return Row(
      children: [
        Expanded(
          child: pasteHint == null
              ? const SizedBox.shrink()
              : Text(pasteHint, style: Theme.of(context).textTheme.bodySmall),
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

/// One saved torrent. The row itself watches (or continues) it; the rarer
/// actions sit in its menu, which a long press or a right click also opens.
class _TorrentRow extends StatefulWidget {
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
  State<_TorrentRow> createState() => _TorrentRowState();
}

class _TorrentRowState extends State<_TorrentRow> {
  final _menu = MenuController();
  bool _menuOpen = false;

  void _setMenuOpen(bool open) {
    if (mounted) setState(() => _menuOpen = open);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      // Also while its menu is open, which then plainly acts on this row.
      color: widget.highlighted || _menuOpen
          ? theme.colorScheme.surfaceContainer
          : Colors.transparent,
      child: InkWell(
        key: const Key('saved_torrent_watch_button'),
        onTap: widget.onWatch,
        onLongPress: _menu.open,
        onSecondaryTap: _menu.open,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 0, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.torrent.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    _Status(torrent: widget.torrent, progress: widget.progress),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RowMenu(
                controller: _menu,
                torrent: widget.torrent,
                onDownload: widget.onDownload,
                onOpenChanged: _setMenuOpen,
              ),
              if (widget.wide)
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

/// Where the user is in the torrent: the episode and how far into it on
/// one line over its bar, or, before anything was watched, when the
/// torrent was added or opened. The file's own name is left out when it
/// has an episode number: it mostly repeats the torrent's.
class _Status extends StatelessWidget {
  const _Status({required this.torrent, required this.progress});

  final SavedTorrent torrent;
  final WatchProgress? progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.bodySmall;
    final progress = this.progress;
    if (progress == null) {
      final used = torrent.lastUsedAt.toLocal();
      final format = used.year == DateTime.now().year
          ? DateFormat.MMMd(l10n.localeName)
          : DateFormat.yMMMd(l10n.localeName);
      final date = format.format(used);
      return Text(
        torrent.lastOpenedAt == null
            ? l10n.savedTorrentsAddedOn(date)
            : l10n.savedTorrentsOpenedOn(date),
        style: style,
      );
    }
    final episode = episodeNumberFromFileName(progress.fileName);
    final file = fileDisplayName(progress.fileName);
    if (progress.isFinished) {
      // Which episode is done, not the torrent: a batch goes on.
      return Row(
        children: [
          PixelIcon(
            PixelGlyph.check,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              episode == null
                  ? l10n.savedTorrentsFileWatched(file)
                  : l10n.savedTorrentsEpisodeWatched(episode),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      );
    }
    final times =
        '${formatPlaybackPosition(progress.position)} / '
        '${formatPlaybackPosition(progress.duration)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${episode == null ? file : l10n.playerEpisodeNumber(episode)}'
          ' · $times',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: WatchProgressLine.maxWidth,
          ),
          child: ExcludeSemantics(
            child: SegmentedBar(
              value: progress.fraction,
              height: 4,
              segment: 6,
            ),
          ),
        ),
      ],
    );
  }
}

enum _MenuAction { download, rename, copyLink, delete }

class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.controller,
    required this.torrent,
    required this.onDownload,
    required this.onOpenChanged,
  });

  final MenuController controller;
  final SavedTorrent torrent;
  final VoidCallback onDownload;
  final ValueChanged<bool> onOpenChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    MenuItemButton item(_MenuAction action, String label) => MenuItemButton(
      key: ValueKey('saved_torrent_${action.name}'),
      onPressed: () => _handle(context, action),
      child: Text(label),
    );
    return RowMenuButton(
      controller: controller,
      tooltip: l10n.savedTorrentsMoreTooltip,
      onOpenChanged: onOpenChanged,
      menuChildren: [
        item(_MenuAction.download, l10n.downloadsOpenButton),
        item(_MenuAction.rename, asksForMore(l10n.savedTorrentsRename)),
        item(_MenuAction.copyLink, l10n.savedTorrentsCopyLink),
        // Apart from the rest, so it is not hit on the way to them.
        const Divider(height: 1),
        item(_MenuAction.delete, l10n.savedTorrentsDelete),
      ],
    );
  }

  Future<void> _handle(BuildContext context, _MenuAction action) async {
    final cubit = context.read<SavedTorrentsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case _MenuAction.download:
        onDownload();
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
        // Cheap to put back, so no question first: an undo instead.
        final removed = await cubit.delete(torrent.infoHash);
        if (removed == null) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.savedTorrentsDeleted),
              action: SnackBarAction(
                label: l10n.commonUndo,
                onPressed: () => cubit.restore(removed),
              ),
            ),
          );
    }
  }
}
