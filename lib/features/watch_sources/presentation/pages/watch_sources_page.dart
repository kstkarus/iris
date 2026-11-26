import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/anime/domain/anime_titles.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_cubit.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_state.dart';
import 'package:iris/features/online_sources/presentation/widgets/online_releases_list.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';
import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';
import 'package:iris/features/saved_torrents/presentation/cubit/saved_torrents_cubit.dart';
import 'package:iris/features/saved_torrents/presentation/widgets/add_saved_torrent_sheet.dart';
import 'package:iris/features/saved_torrents/presentation/widgets/saved_torrents_list.dart';
import 'package:iris/features/settings/presentation/anime_title_labels.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_sources_tab.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_cubit.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_state.dart';
import 'package:iris/features/watch_sources/presentation/cubit/watch_sources_tab_cubit.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/features/watch_sources/presentation/widgets/watch_sources_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/torrent/torrent_file_picker.dart';
import 'package:iris/shared/utils/bayer_mask.dart';
import 'package:iris/shared/utils/desktop_platform.dart';
import 'package:iris/shared/utils/equality.dart';
import 'package:iris/shared/widgets/active_layer.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/desktop_dossier_metrics.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_scroll_edge.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/dither_transition.dart';
import 'package:iris/shared/widgets/marked_tab.dart';
import 'package:iris/shared/widgets/page_title.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/poster_image.dart';

/// Reusable controller + view builder for Watch Sources (online dubs, torrents,
/// and saved torrents), shared by both standalone [WatchSourcesPage] and the
/// inline desktop dossier flow inside `AnimeDetailsPage`.
class WatchSourcesHost extends StatefulWidget {
  const WatchSourcesHost({
    required this.args,
    required this.builder,
    this.downloadsRepository,
    this.pickFile = pickTorrentFile,
    this.active = true,
    this.desktopSplit = false,
    this.onOpenSource,
    super.key,
  });

  final AnimeWatchSourcesArgs args;
  final DownloadsRepository? downloadsRepository;
  final TorrentFilePicker pickFile;

  /// Enables keyboard clipboard paste (`Ctrl+V` / `⌘V`) only while the
  /// sources panel is the active step.
  final bool active;
  final bool desktopSplit;

  /// Optional inline handler when embedded inside desktop `AnimeDetailsPage`.
  final ValueChanged<AnimePlayerSourceArgs>? onOpenSource;

  final Widget Function(
    BuildContext context, {
    required Widget pane,
    required Widget addButton,
  })
  builder;

  @override
  State<WatchSourcesHost> createState() => _WatchSourcesHostState();
}

class _WatchSourcesHostState extends State<WatchSourcesHost> {
  bool _keepMineUntilEmpty = false;
  late final _downloadedCounts = widget.downloadsRepository
      ?.watchDownloads()
      .map((items) {
        final counts = <String, int>{};
        for (final item in items) {
          if (item.status == DownloadStatus.completed) {
            final key = downloadSourceKey(item.magnet);
            counts.update(key, (count) => count + 1, ifAbsent: () => 1);
          }
        }
        return counts;
      })
      .distinct(sameMap);

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

    final desktopSplit = widget.desktopSplit;
    final largeText = DetailLayout.isLargeText(context);
    final sizeClass = WindowSizeClass.of(context);
    final margin = sizeClass.pageMargin;
    final listHorizontalPadding = desktopSplit ? 12.0 : margin;
    final tabHorizontalPadding = desktopSplit ? 0.0 : margin;
    final tabular = desktopSplit && !largeText;

    final addTooltip = isDesktopPlatform
        ? l10n.savedTorrentsAddWithShortcut(
            defaultTargetPlatform == TargetPlatform.macOS ? '⌘V' : 'Ctrl+V',
          )
        : l10n.savedTorrentsAddButton;

    final addButton = desktopSplit && !largeText
        ? Tooltip(
            message: addTooltip,
            child: TextButton.icon(
              key: WatchSourcesPage.addButtonKey,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () => _add(context),
              icon: const PixelIcon(PixelGlyph.plus, size: 15),
              label: Text(l10n.savedTorrentsAddButton),
            ),
          )
        : IconButton(
            key: WatchSourcesPage.addButtonKey,
            tooltip: addTooltip,
            icon: const PixelIcon(PixelGlyph.plus, size: 20),
            onPressed: () => _add(context),
          );

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyV, control: true): _PasteIntent(),
        SingleActivator(LogicalKeyboardKey.keyV, meta: true): _PasteIntent(),
      },
      child: Actions(
        actions: {
          _PasteIntent: _PasteTorrentAction(
            () => _addFromClipboard(context),
            enabled: widget.active,
          ),
        },
        // The host's own scope: focus that leaves the torrent search stays
        // under the paste shortcut.
        child: FocusScope(
          autofocus: widget.active,
          child: StreamBuilder<Map<String, int>>(
            stream: _downloadedCounts,
            builder: (context, snapshot) {
              final downloadedCounts = snapshot.data ?? const <String, int>{};
              final pane = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The strip gives its height back when one kind is left.
                  DitherSwitcher(
                    collapse: true,
                    resizeDuration: const Duration(milliseconds: 200),
                    duration: const Duration(milliseconds: 220),
                    child: tabs.length > 1
                        ? Padding(
                            key: const ValueKey('source_tabs'),
                            padding: EdgeInsets.fromLTRB(
                              tabHorizontalPadding,
                              0,
                              tabHorizontalPadding,
                              8,
                            ),
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
                              ? DitherScrollEdge(
                                  child: OnlineReleasesList(
                                    animeId: args.animeId,
                                    animeTitles: args.animeTitles,
                                    posterUrl: args.posterUrl,
                                    downloadedCounts: downloadedCounts,
                                    horizontalPadding: listHorizontalPadding,
                                    tabular: tabular,
                                    onOpenSource: widget.onOpenSource,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        _TabPane(
                          active: tab == WatchSourcesTab.torrents,
                          child: WatchSourcesView(
                            onAddTorrent: () => _add(context),
                            posterUrl: args.posterUrl,
                            downloadedCounts: downloadedCounts,
                            horizontalPadding: listHorizontalPadding,
                            desktopSplit: desktopSplit,
                            onOpenSource: widget.onOpenSource,
                          ),
                        ),
                        _TabPane(
                          active: tab == WatchSourcesTab.mine,
                          child: showMine
                              ? DitherScrollEdge(
                                  child: SavedTorrentsList(
                                    onEmptied: _onMineEmptied,
                                    onWatch: (torrent) =>
                                        _watch(context, torrent),
                                    horizontalPadding: listHorizontalPadding,
                                    tabular: tabular,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              return widget.builder(context, pane: pane, addButton: addButton);
            },
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

  void _watch(BuildContext context, SavedTorrent torrent) {
    context.read<SavedTorrentsCubit>().markOpened(torrent);
    final sourceArgs = AnimePlayerSourceArgs(
      animeId: args.animeId,
      animeTitles: args.animeTitles,
      sourceTitle: torrent.title,
      magnet: torrent.magnet,
      posterUrl: args.posterUrl,
    );
    final handler = widget.onOpenSource;
    if (handler != null) {
      handler(sourceArgs);
      return;
    }
    context.pushNamed('torrent-stream-files', extra: sourceArgs);
  }
}

/// Online releases, torrents and the torrents the user added, each on its
/// own tab with the whole page: people pick one kind and seldom compare
/// across them. A kind with nothing takes its tab away, so a tab never
/// opens on nothing; with one kind left the page is that kind alone.
///
/// On desktop windows the page shares [DesktopDossierMetrics] with anime
/// details, character pages, and the episode picker.
///
/// The bar's add button (and, with a keyboard, a paste) adds a torrent of
/// the user's own to this anime, so what plays from it is known to be this
/// anime. It is there however the search went, including when it found
/// nothing.
class WatchSourcesPage extends StatelessWidget {
  const WatchSourcesPage({
    required this.args,
    this.downloadsRepository,
    this.pickFile = pickTorrentFile,
    super.key,
  });

  static const addButtonKey = Key('watch_sources_add_torrent_button');

  static bool isDesktopSplit(BuildContext context) =>
      DesktopDossierMetrics.isStandaloneSplit(context);

  final AnimeWatchSourcesArgs args;
  final DownloadsRepository? downloadsRepository;
  final TorrentFilePicker pickFile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = watchAnimeTitleLabels(context, args.animeTitles).primary;
    final desktopSplit = isDesktopSplit(context);
    final sizeClass = WindowSizeClass.of(context);
    final margin = sizeClass.pageMargin;
    final topGap = sizeClass.isCompact ? 16.0 : 24.0;

    return WatchSourcesHost(
      args: args,
      downloadsRepository: downloadsRepository,
      pickFile: pickFile,
      desktopSplit: desktopSplit,
      builder: (context, {required pane, required addButton}) {
        return Scaffold(
          appBar: FramedAppBar(
            title: PageTitle(
              title: l10n.watchSourcesTitle,
              subtitle: desktopSplit ? null : title,
            ),
            trailing: addButton,
          ),
          body: SafeArea(
            child: MaxWidthBox(
              maxWidth: AdaptiveContentWidth.page + margin * 2,
              child: !desktopSplit
                  ? Padding(
                      padding: EdgeInsets.only(top: topGap),
                      child: pane,
                    )
                  : Padding(
                      padding: EdgeInsets.symmetric(horizontal: margin),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: DesktopDossierMetrics.railWidth(sizeClass),
                            child: _DesktopSourceRail(
                              animeTitles: args.animeTitles,
                              posterUrl: args.posterUrl,
                              topPadding: topGap,
                            ),
                          ),
                          SizedBox(width: DesktopDossierMetrics.gap(sizeClass)),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: topGap),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        DesktopDossierMetrics.workspaceMaxWidth(
                                          sizeClass,
                                        ),
                                  ),
                                  child: pane,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Sticky left dossier rail on standalone desktop windows: cover art and
/// primary anime title on the shared [DesktopDossierMetrics] grid.
class _DesktopSourceRail extends StatelessWidget {
  const _DesktopSourceRail({
    required this.animeTitles,
    required this.posterUrl,
    required this.topPadding,
  });

  final AnimeTitles animeTitles;
  final String posterUrl;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rule = DetailLayout.ruleColor(scheme);
    final primaryTitle = watchAnimeTitleLabels(context, animeTitles).primary;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(0, topPadding, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (posterUrl.isNotEmpty) ...[
            PosterImage(url: posterUrl, borderColor: rule),
            const SizedBox(height: 16),
          ],
          if (primaryTitle.isNotEmpty)
            Text(
              primaryTitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFamily: DetailLayout.sansFont,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: scheme.onSurface,
              ),
            ),
        ],
      ),
    );
  }
}

/// Keeps each tab mounted and develops the newly selected one cell by cell
/// through the Bayer screen so scroll positions and torrent search stay intact.
class _TabPane extends StatefulWidget {
  const _TabPane({required this.active, required this.child});

  static const _duration = Duration(milliseconds: 220);

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
          child: AnimatedBuilder(
            animation: _controller,
            child: widget.child,
            builder: (context, child) => BayerMasked(
              open: (_controller.value * BayerMask.steps).round(),
              child: child,
            ),
          ),
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
  _PasteTorrentAction(this._add, {required this.enabled});

  final VoidCallback _add;
  final bool enabled;

  @override
  bool isEnabled(_PasteIntent intent) =>
      enabled &&
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
    return SizedBox(
      width: double.infinity,
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
                  WatchSourcesTab.torrents => l10n.watchSourcesTorrentsSection,
                  WatchSourcesTab.mine => l10n.watchSourcesMineSection,
                },
                selected: tab == selected,
                onTap: () => cubit.select(tab),
              ),
          ],
        ),
      ),
    );
  }
}
