import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_cubit.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_state.dart';
import 'package:iris/features/online_sources/presentation/widgets/online_releases_list.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';
import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';
import 'package:iris/features/saved_torrents/presentation/cubit/saved_torrents_cubit.dart';
import 'package:iris/features/saved_torrents/presentation/widgets/add_saved_torrent_sheet.dart';
import 'package:iris/features/saved_torrents/presentation/widgets/saved_torrents_list.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_sources_tab.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_state.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_tab_cubit.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/features/watch_sources/presentation/widgets/watch_sources_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/torrent/torrent_file_picker.dart';
import 'package:iris/shared/utils/desktop_platform.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/dither_transition.dart';
import 'package:iris/shared/widgets/page_title.dart';
import 'package:iris/shared/widgets/marked_tab.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

/// Online releases, torrents and the torrents the user added, each on its
/// own tab with the whole page: people pick one kind and seldom compare
/// across them. A kind with nothing takes its tab away, so a tab never
/// opens on nothing; with one kind left the page is that kind alone.
///
/// The bar's add button (and, with a keyboard, a paste) adds a torrent of
/// the user's own to this anime, so what plays from it is known to be this
/// anime. It is there however the search went, including when it found
/// nothing.
class WatchSourcesPage extends StatelessWidget {
  const WatchSourcesPage({
    required this.args,
    this.pickFile = pickTorrentFile,
    super.key,
  });

  static const addButtonKey = Key('watch_sources_add_torrent_button');

  final AnimeWatchSourcesArgs args;
  final TorrentFilePicker pickFile;

  @override
  Widget build(BuildContext context) {
    final hasOnline = context.select<OnlineReleasesCubit, bool>(
      (cubit) => cubit.state is! OnlineReleasesEmpty,
    );
    final hasTorrents = context.select<WatchSourcesCubit, bool>(
      (cubit) => cubit.state is! WatchSourcesEmpty,
    );
    final hasMine = context.select<SavedTorrentsCubit, bool>(
      (cubit) => cubit.state.torrents.isNotEmpty,
    );
    return _Lingering(
      value: hasMine,
      // The last row dissolves before its tab goes.
      linger: DitherTransition.duration * 2,
      builder: (context, hasMine) =>
          _build(context, hasOnline, hasTorrents, hasMine),
    );
  }

  Widget _build(
    BuildContext context,
    bool hasOnline,
    bool hasTorrents,
    bool hasMine,
  ) {
    final l10n = AppLocalizations.of(context);
    final tabs = [
      if (hasOnline) WatchSourcesTab.online,
      if (hasTorrents) WatchSourcesTab.torrents,
      if (hasMine) WatchSourcesTab.mine,
    ];
    final chosen = context.watch<WatchSourcesTabCubit>().state;
    final tab = tabs.contains(chosen)
        ? chosen
        // With nothing anywhere, the torrents say so and offer to add one.
        : tabs.firstOrNull ?? WatchSourcesTab.torrents;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyV, control: true): _PasteIntent(),
        SingleActivator(LogicalKeyboardKey.keyV, meta: true): _PasteIntent(),
      },
      child: Actions(
        actions: {
          _PasteIntent: _PasteTorrentAction(() => _addFromClipboard(context)),
        },
        // The page's own scope: focus that leaves the torrent search stays
        // under the paste shortcut.
        child: FocusScope(
          autofocus: true,
          child: Scaffold(
            appBar: FramedAppBar(
              title: PageTitle(
                title: l10n.watchSourcesTitle,
                subtitle: args.animeTitle,
              ),
              trailing: IconButton(
                key: addButtonKey,
                tooltip: isDesktopPlatform
                    ? l10n.savedTorrentsAddWithShortcut(
                        defaultTargetPlatform == TargetPlatform.macOS
                            ? '⌘V'
                            : 'Ctrl+V',
                      )
                    : l10n.savedTorrentsAddButton,
                icon: const PixelIcon(PixelGlyph.plus, size: 20),
                onPressed: () => _add(context),
              ),
            ),
            body: PageFrame.subPage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The tabs go once one kind is left: they dissolve, then
                  // give their height back. A kind coming or going changes
                  // the row in place.
                  DitherSwitcher(
                    collapse: true,
                    child: tabs.length > 1
                        ? Padding(
                            key: ValueKey(tabs.map((tab) => tab.name).join()),
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _Tabs(tabs: tabs, selected: tab),
                          )
                        : const SizedBox.shrink(key: ValueKey('no_tabs')),
                  ),
                  // All stay built, so each keeps its scroll and the torrent
                  // search while another is shown.
                  Expanded(
                    child: IndexedStack(
                      index: tab.index,
                      sizing: StackFit.expand,
                      children: [
                        TickerMode(
                          enabled: tab == WatchSourcesTab.online,
                          child: hasOnline
                              ? OnlineReleasesList(
                                  animeId: args.animeId,
                                  animeTitle: args.animeTitle,
                                  posterUrl: args.posterUrl,
                                )
                              : const SizedBox.shrink(),
                        ),
                        TickerMode(
                          enabled: tab == WatchSourcesTab.torrents,
                          child: WatchSourcesView(
                            onAddTorrent: () => _add(context),
                            posterUrl: args.posterUrl,
                          ),
                        ),
                        TickerMode(
                          enabled: tab == WatchSourcesTab.mine,
                          child: SavedTorrentsList(
                            onWatch: (torrent, {autoOpenFileIndex}) =>
                                _watch(context, torrent, autoOpenFileIndex),
                            onDownload: (torrent) =>
                                _download(context, torrent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addFromClipboard(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!context.mounted) return;
    await _add(context, initialMagnet: data?.text?.trim());
  }

  /// Adds a torrent, then shows it where it went: the user's tab.
  Future<void> _add(BuildContext context, {String? initialMagnet}) async {
    final cubit = context.read<SavedTorrentsCubit>();
    final tabs = context.read<WatchSourcesTabCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final result = await showAddSavedTorrentSheet(
      context: context,
      onSave: cubit.add,
      initialMagnet: initialMagnet,
      pickFile: pickFile,
    );
    switch (result) {
      case SaveTorrentAdded():
        await tabs.select(WatchSourcesTab.mine);
      case SaveTorrentDuplicate(:final existing):
        await tabs.select(WatchSourcesTab.mine);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.savedTorrentsDuplicate(existing.title)),
            ),
          );
      case SaveTorrentInvalidMagnet() || null:
        break;
    }
  }

  void _watch(BuildContext context, SavedTorrent torrent, int? fileIndex) {
    context.read<SavedTorrentsCubit>().markOpened(torrent);
    context.pushNamed(
      'torrent-stream-files',
      extra: AnimePlayerSourceArgs(
        animeId: args.animeId,
        animeTitle: args.animeTitle,
        sourceTitle: torrent.title,
        magnet: torrent.magnet,
        autoOpenFileIndex: fileIndex,
      ),
    );
  }

  void _download(BuildContext context, SavedTorrent torrent) {
    context.read<SavedTorrentsCubit>().markOpened(torrent);
    context.pushNamed(
      'torrent-download-files',
      extra: DownloadSelectionArgs(
        animeId: args.animeId,
        animeTitle: args.animeTitle,
        posterUrl: args.posterUrl,
        sourceTitle: torrent.title,
        magnet: torrent.magnet,
      ),
    );
  }
}

/// [value] as it turns true at once, and as it turns false only after
/// [linger], unless it turns back meanwhile.
class _Lingering extends StatefulWidget {
  const _Lingering({
    required this.value,
    required this.linger,
    required this.builder,
  });

  final bool value;
  final Duration linger;
  final Widget Function(BuildContext context, bool value) builder;

  @override
  State<_Lingering> createState() => _LingeringState();
}

class _LingeringState extends State<_Lingering> {
  late bool _value = widget.value;
  Timer? _timer;

  @override
  void didUpdateWidget(covariant _Lingering oldWidget) {
    super.didUpdateWidget(oldWidget);
    _timer?.cancel();
    if (widget.value) {
      _value = true;
    } else if (_value) {
      final linger = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : widget.linger;
      _timer = Timer(linger, () {
        if (mounted) setState(() => _value = false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}

class _PasteIntent extends Intent {
  const _PasteIntent();
}

/// A paste on the page adds a torrent; in a text field (the torrent
/// search) it stays the field's own paste.
class _PasteTorrentAction extends Action<_PasteIntent> {
  _PasteTorrentAction(this._add);

  final VoidCallback _add;

  @override
  bool isEnabled(_PasteIntent intent) =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorStateOfType<EditableTextState>() ==
      null;

  @override
  void invoke(_PasteIntent intent) => _add();
}

/// The page's views as the app's own sections are: text tabs, the current
/// one marked. The glyph of the first tab lines up with the content.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.tabs, required this.selected});

  /// [MarkedTab]'s own padding, pulled back over the page margin.
  static const _inset = 10.0;

  final List<WatchSourcesTab> tabs;
  final WatchSourcesTab selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<WatchSourcesTabCubit>();
    return Transform.translate(
      offset: const Offset(-_inset, 0),
      // Large text on a narrow phone puts the last tab on a line of its own
      // rather than past the edge.
      child: Wrap(
        children: [
          for (final tab in tabs)
            MarkedTab(
              label: switch (tab) {
                WatchSourcesTab.online => l10n.watchSourcesOnlineSection,
                WatchSourcesTab.torrents => l10n.watchSourcesTorrentsSection,
                WatchSourcesTab.mine => l10n.watchSourcesMineSection,
              },
              selected: tab == selected,
              onTap: () => cubit.select(tab),
            ),
        ],
      ),
    );
  }
}
