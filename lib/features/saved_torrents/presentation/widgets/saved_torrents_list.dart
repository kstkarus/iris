import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_line.dart';
import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';
import 'package:iris/features/saved_torrents/presentation/cubit/saved_torrents_cubit.dart';
import 'package:iris/features/saved_torrents/presentation/widgets/saved_torrent_dialogs.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/haptics/app_haptics.dart';
import 'package:iris/shared/torrent/torrent_key.dart';
import 'package:iris/shared/utils/desktop_platform.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/utils/episode_number.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_list.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/focusable_list_row.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';
import 'package:iris/shared/widgets/row_menu_button.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

/// The torrents the user added to an anime, most recently used first. Rows
/// added or deleted while the list shows come and go cell by cell.
class SavedTorrentsList extends StatelessWidget {
  const SavedTorrentsList({
    required this.onWatch,
    this.onEmptied,
    this.horizontalPadding = 0,
    this.tabular = false,
    super.key,
  });

  final ValueChanged<SavedTorrent> onWatch;
  final VoidCallback? onEmptied;

  /// Horizontal gutter inside rows so tap/hover fills can bleed edge-to-edge
  /// while text and dividers align with the page frame.
  final double horizontalPadding;

  /// True inside the desktop split layout.
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SavedTorrentsCubit>().state;
    final latestProgress = {
      for (final progress in latestPerTorrent(context.watchWatchProgress()))
        progress.torrentKey: progress,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            tabular || constraints.maxWidth >= WindowSizeClass.mediumMinWidth;
        final scheme = Theme.of(context).colorScheme;
        final dividerColor = DetailLayout.ruleColor(
          scheme,
        ).withValues(alpha: 0.45);
        final list = DitherList<SavedTorrent>(
          padding: const EdgeInsets.only(bottom: 24),
          removalDuration: const Duration(milliseconds: 360),
          onEmptied: onEmptied,
          items: state.torrents,
          keyOf: (torrent) => torrent.infoHash,
          separator: Divider(
            height: 1,
            thickness: 1,
            indent: tabular ? 0 : horizontalPadding,
            endIndent: tabular ? 0 : horizontalPadding,
            color: dividerColor,
          ),
          itemBuilder: (context, torrent) {
            final progress =
                latestProgress[torrentKeyFromMagnet(torrent.magnet)];
            final highlighted = torrent.infoHash == state.highlightedInfoHash;
            final active = progress != null && !progress.isFinished;
            return DecoratedBox(
              decoration: BoxDecoration(
                border: tabular
                    ? Border(
                        left: BorderSide(
                          width: 2,
                          color: highlighted || active
                              ? scheme.onSurface
                              : Colors.transparent,
                        ),
                      )
                    : null,
              ),
              child: _TorrentRow(
                torrent: torrent,
                progress: progress,
                highlighted: highlighted,
                wide: wide,
                horizontalPadding: horizontalPadding,
                onWatch: () => onWatch(torrent),
              ),
            );
          },
        );
        if (!tabular) return list;
        return FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  FocusScope.of(context).nextFocus(),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  FocusScope.of(context).previousFocus(),
            },
            child: list,
          ),
        );
      },
    );
  }
}

/// One saved torrent. The row opens its release; the rarer
/// actions sit in its menu, which a long press or a right click also opens.
/// The Delete key deletes it, as the menu does.
class _TorrentRow extends StatefulWidget {
  const _TorrentRow({
    required this.torrent,
    required this.progress,
    required this.highlighted,
    required this.wide,
    required this.horizontalPadding,
    required this.onWatch,
  });

  final SavedTorrent torrent;

  /// The torrent's most recently watched file.
  final WatchProgress? progress;
  final bool highlighted;

  /// Wide rows end in an arrow, like the catalog's rows; narrow ones
  /// leave the width to the title.
  final bool wide;
  final double horizontalPadding;
  final VoidCallback onWatch;

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
    final trailingPadding = widget.wide
        ? widget.horizontalPadding
        : (widget.horizontalPadding - 10).clamp(0.0, double.infinity);
    return FocusableListRow(
      inkKey: const Key('saved_torrent_watch_button'),
      onDelete: () => _deleteWithUndo(context, widget.torrent),
      // Also while its menu is open, which then plainly acts on this row.
      filled: widget.highlighted || _menuOpen,
      onTap: widget.onWatch,
      onLongPress: () {
        if (_menu.isOpen) return;
        _menu.open();
        if (_menu.isOpen) AppHaptics.medium();
      },
      onSecondaryTap: _menu.open,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          widget.horizontalPadding,
          14,
          trailingPadding,
          14,
        ),
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
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: DetailLayout.sansFont,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      height: 1.32,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _Status(torrent: widget.torrent, progress: widget.progress),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _RowMenu(
              controller: _menu,
              torrent: widget.torrent,
              onOpenChanged: _setMenuOpen,
            ),
            if (widget.wide)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: PixelIcon(
                  PixelGlyph.arrowRight,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
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

  static const _duration = Duration(milliseconds: 180);

  final SavedTorrent torrent;
  final WatchProgress? progress;

  @override
  Widget build(BuildContext context) {
    final (Object key, Widget content) = _buildMode(context);
    return SizedBox(
      width: double.infinity,
      child: DitherSwitcher(
        duration: _duration,
        resizeDuration: _duration,
        child: KeyedSubtree(key: ValueKey(key), child: content),
      ),
    );
  }

  (Object, Widget) _buildMode(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;
    final sansStyle = style?.copyWith(
      fontFamily: DetailLayout.sansFont,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final monoStyle = DetailLayout.monoTelemetryStyle(
      style,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final progress = this.progress;
    if (progress == null) {
      final used = torrent.lastUsedAt.toLocal();
      final format = used.year == DateTime.now().year
          ? DateFormat.MMMd(l10n.localeName)
          : DateFormat.yMMMd(l10n.localeName);
      final date = format.format(used);
      return (
        'unwatched',
        MixedDataText(
          torrent.lastOpenedAt == null
              ? l10n.savedTorrentsAddedOn(date)
              : l10n.savedTorrentsOpenedOn(date),
          sansStyle: sansStyle,
          monoStyle: monoStyle,
        ),
      );
    }
    final episode = episodeNumberFromFileName(progress.fileName);
    final file = fileDisplayName(progress.fileName);
    if (progress.isFinished) {
      // Which episode is done, not the torrent: a batch goes on.
      return (
        'finished',
        Row(
          children: [
            PixelIcon(
              PixelGlyph.check,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: MixedDataText(
                episode == null
                    ? l10n.savedTorrentsFileWatched(file)
                    : l10n.savedTorrentsEpisodeWatched(episode),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                sansStyle: sansStyle,
                monoStyle: monoStyle,
              ),
            ),
          ],
        ),
      );
    }
    final times =
        '${formatPlaybackPosition(progress.position)} / '
        '${formatPlaybackPosition(progress.duration)}';
    return (
      'in_progress',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelSeparatedText.parts(
            [episode == null ? file : l10n.playerEpisodeNumber(episode), times],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            sansStyle: sansStyle,
            monoStyle: monoStyle,
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: WatchProgressLine.maxWidth,
            ),
            child: ExcludeSemantics(
              child: SegmentedBar(
                value: progress.fraction,
                height: 3,
                segment: 6,
                gap: 0,
                color: theme.colorScheme.tertiary,
                trackColor: DetailLayout.progressTrackColor(
                  theme.colorScheme,
                ).withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MenuAction { rename, copyLink, delete }

class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.controller,
    required this.torrent,
    required this.onOpenChanged,
  });

  final MenuController controller;
  final SavedTorrent torrent;
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
      tooltip: l10n.commonMoreActions,
      onOpenChanged: onOpenChanged,
      menuChildren: [
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
      case _MenuAction.rename:
        final title = await showRenameSavedTorrentDialog(
          context: context,
          currentTitle: torrent.title,
        );
        if (title != null) await cubit.rename(torrent, title);
      case _MenuAction.copyLink:
        await Clipboard.setData(ClipboardData(text: torrent.magnet));
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.savedTorrentsLinkCopied)),
        );
      case _MenuAction.delete:
        await _deleteWithUndo(context, torrent);
    }
  }
}

/// Cheap to put back, so no question first: an undo instead.
Future<void> _deleteWithUndo(BuildContext context, SavedTorrent torrent) async {
  final cubit = context.read<SavedTorrentsCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  AppHaptics.medium();
  await cubit.delete(torrent);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l10n.savedTorrentsDeleted),
        action: SnackBarAction(
          label: l10n.commonUndo,
          onPressed: () => cubit.restore(torrent),
        ),
      ),
    );
}
