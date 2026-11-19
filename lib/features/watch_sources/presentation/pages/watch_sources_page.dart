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
import 'package:iris/shared/widgets/active_layer.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
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
class WatchSourcesPage extends StatefulWidget {
  const WatchSourcesPage({
    required this.args,
    this.pickFile = pickTorrentFile,
    super.key,
  });

  static const addButtonKey = Key('watch_sources_add_torrent_button');

  final AnimeWatchSourcesArgs args;
  final TorrentFilePicker pickFile;

  @override
  State<WatchSourcesPage> createState() => _WatchSourcesPageState();
}

class _WatchSourcesPageState extends State<WatchSourcesPage> {
  bool _keepMineUntilEmpty = false;

  AnimeWatchSourcesArgs get args => widget.args;

  void _onMineEmptied() {
    if (_keepMineUntilEmpty &&
        context.read<SavedTorrentsCubit>().state.torrents.isEmpty) {
      setState(() => _keepMineUntilEmpty = false);
    }
  }

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
    final l10n = AppLocalizations.of(context);
    final chosen = context.watch<WatchSourcesTabCubit>().state;
    final tabs = [
      if (hasOnline) WatchSourcesTab.online,
      if (hasTorrents) WatchSourcesTab.torrents,
    ];
    // Only the selected list can visibly finish removing its last row.
    final showMine =
        hasMine ||
        (_keepMineUntilEmpty &&
            (chosen == WatchSourcesTab.mine || tabs.isEmpty) &&
            !MediaQuery.disableAnimationsOf(context));
    if (showMine) tabs.add(WatchSourcesTab.mine);
    final tab = tabs.contains(chosen)
        ? chosen
        // With nothing anywhere, the torrents say so and offer to add one.
        : tabs.firstOrNull ?? WatchSourcesTab.torrents;
    _keepMineUntilEmpty = tab == WatchSourcesTab.mine;

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
                key: WatchSourcesPage.addButtonKey,
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
                  // The strip gives its height back when one kind is left.
                  DitherSwitcher(
                    collapse: true,
                    duration: const Duration(milliseconds: 220),
                    child: tabs.length > 1
                        ? Padding(
                            key: const ValueKey('source_tabs'),
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _Tabs(tabs: tabs, selected: tab),
                          )
                        : const SizedBox.shrink(key: ValueKey('no_tabs')),
                  ),
                  // Hidden tabs keep their scroll and the torrent search.
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _TabPane(
                          active: tab == WatchSourcesTab.online,
                          child: hasOnline
                              ? OnlineReleasesList(
                                  animeId: args.animeId,
                                  animeTitle: args.animeTitle,
                                  posterUrl: args.posterUrl,
                                )
                              : const SizedBox.shrink(),
                        ),
                        _TabPane(
                          active: tab == WatchSourcesTab.torrents,
                          child: WatchSourcesView(
                            onAddTorrent: () => _add(context),
                            posterUrl: args.posterUrl,
                          ),
                        ),
                        _TabPane(
                          active: tab == WatchSourcesTab.mine,
                          child: showMine
                              ? SavedTorrentsList(
                                  onEmptied: _onMineEmptied,
                                  onWatch: (torrent, {autoOpenFileIndex}) =>
                                      _watch(
                                        context,
                                        torrent,
                                        autoOpenFileIndex,
                                      ),
                                  onDownload: (torrent) =>
                                      _download(context, torrent),
                                )
                              : const SizedBox.shrink(),
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
      pickFile: widget.pickFile,
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

/// Keeps each tab mounted and fades in the newly selected one.
class _TabPane extends StatefulWidget {
  const _TabPane({required this.active, required this.child});

  static const _duration = Duration(milliseconds: 150);

  final bool active;
  final Widget child;

  @override
  State<_TabPane> createState() => _TabPaneState();
}

class _TabPaneState extends State<_TabPane>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _TabPane._duration,
    value: 1,
  );
  late final Animation<double> _opacity = _controller.drive(
    CurveTween(curve: Curves.easeOutCubic),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant _TabPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !widget.active,
      child: TickerMode(
        enabled: widget.active,
        child: ActiveLayer(
          active: widget.active,
          child: FadeTransition(opacity: _opacity, child: widget.child),
        ),
      ),
    );
  }
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
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: DetailLayout.ruleColor(scheme)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Transform.translate(
            offset: const Offset(-_inset, 0),
            // Large text on a narrow phone puts the last tab on a line of its own
            // rather than past the edge.
            child: Wrap(
              children: [
                for (final tab in tabs)
                  MarkedTab(
                    label: switch (tab) {
                      WatchSourcesTab.online => l10n.watchSourcesOnlineSection,
                      WatchSourcesTab.torrents =>
                        l10n.watchSourcesTorrentsSection,
                      WatchSourcesTab.mine => l10n.watchSourcesMineSection,
                    },
                    selected: tab == selected,
                    onTap: () => cubit.select(tab),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
