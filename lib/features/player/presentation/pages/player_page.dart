import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';
import 'package:iris/features/player/presentation/widgets/player_episodes_list.dart';
import 'package:iris/features/player/presentation/widgets/player_view.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/page_title.dart';

/// Video with the torrent's episodes as a supporting pane: beside the video
/// on expanded and landscape windows (about 70/30, can be hidden), below it
/// on portrait ones.
class PlayerPage extends StatefulWidget {
  const PlayerPage({required this.viewportFactory, super.key});

  static const episodesToggleKey = Key('player_episodes_toggle');
  static const episodesPaneKey = Key('player_episodes_pane');

  final PlayerViewportFactory viewportFactory;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  bool _sidePaneVisible = true;

  /// Moves the player view, with the full-screen route it tracks, between
  /// the side-by-side and stacked layouts (rotation, window resize).
  final _playerKey = GlobalKey();

  /// The resume snackbar. Its action belongs to the current file, so it
  /// closes when the file changes or the page goes away (a
  /// ScaffoldMessenger would otherwise carry it to the next screen).
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _playbackSnackBar;

  @override
  void dispose() {
    _closePlaybackSnackBar();
    super.dispose();
  }

  void _closePlaybackSnackBar() {
    _playbackSnackBar?.close();
    _playbackSnackBar = null;
  }

  void _showPlaybackSnackBar(BuildContext context, SnackBar snackBar) {
    _closePlaybackSnackBar();
    // One snackbar at a time: this replaces whatever is showing instead of
    // queueing behind it.
    final controller = (ScaffoldMessenger.of(
      context,
    )..hideCurrentSnackBar()).showSnackBar(snackBar);
    _playbackSnackBar = controller;
    controller.closed.then((_) {
      if (identical(_playbackSnackBar, controller)) _playbackSnackBar = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<PlayerCubit>();

    return BlocConsumer<PlayerCubit, PlayerState>(
      listener: _showPlaybackMessages,
      builder: (context, state) {
        final source = cubit.source;
        final hasEpisodes = source.files.length > 1;

        return LayoutBuilder(
          builder: (context, constraints) {
            final sizeClass = WindowSizeClass.fromWidth(constraints.maxWidth);
            // Below the video the list needs height; landscape windows give
            // it room beside the video instead.
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            final sideBySide =
                hasEpisodes &&
                (sizeClass.isAtLeast(WindowSizeClass.expanded) ||
                    (!sizeClass.isCompact && isLandscape));
            final margin = sizeClass.pageMargin;

            return Scaffold(
              appBar: AppBar(
                // Nothing scrolls under the bar: the episode lists scroll in
                // their own pane and must not tint it.
                notificationPredicate: (_) => false,
                title: PageTitle(
                  title: fileDisplayName(source.fileName),
                  subtitle: source.sourceTitle,
                ),
                actions: [
                  if (sideBySide)
                    IconButton(
                      key: PlayerPage.episodesToggleKey,
                      tooltip: _sidePaneVisible
                          ? l10n.playerHideEpisodes
                          : l10n.playerShowEpisodes,
                      isSelected: _sidePaneVisible,
                      icon: const Icon(Icons.playlist_play_outlined),
                      selectedIcon: const Icon(Icons.playlist_play),
                      onPressed: () =>
                          setState(() => _sidePaneVisible = !_sidePaneVisible),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
              body: SafeArea(
                child: sideBySide
                    ? _SideBySideLayout(
                        margin: margin,
                        showPane: _sidePaneVisible,
                        player: PlayerView(
                          key: _playerKey,
                          viewportFactory: widget.viewportFactory,
                        ),
                        pane: _EpisodesPane(source: source),
                      )
                    : _StackedLayout(
                        margin: margin,
                        player: PlayerView(
                          key: _playerKey,
                          viewportFactory: widget.viewportFactory,
                        ),
                        episodes: hasEpisodes
                            ? _EpisodesPane(source: source)
                            : null,
                      ),
              ),
            );
          },
        );
      },
    );
  }

  /// The automatic resume, with "Start over"; it does not interrupt
  /// playback. The next file is offered inside the player (also in full
  /// screen) when a file ends.
  void _showPlaybackMessages(BuildContext context, PlayerState state) {
    if (state is! PlayerReady) {
      _closePlaybackSnackBar();
      return;
    }
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<PlayerCubit>();
    final behavior = _snackBarPlacement(context);

    final startPosition = state.startPosition;
    if (state.showResumeNotice && startPosition != null) {
      cubit.dismissResumeNotice();
      _showPlaybackSnackBar(
        context,
        SnackBar(
          key: const Key('player_resume_snackbar'),
          content: Text(
            l10n.playerResumedFrom(formatPlaybackPosition(startPosition)),
          ),
          action: SnackBarAction(
            label: l10n.playerStartOver,
            onPressed: cubit.restartFromBeginning,
          ),
          duration: const Duration(seconds: 8),
          behavior: behavior.behavior,
          width: behavior.width,
        ),
      );
    }
  }
}

/// Full-width on phones; a floating, width-capped snackbar on larger
/// windows so it does not span the video and the episodes pane.
({SnackBarBehavior behavior, double? width}) _snackBarPlacement(
  BuildContext context,
) {
  final width = MediaQuery.sizeOf(context).width;
  if (WindowSizeClass.fromWidth(width).isCompact) {
    return (behavior: SnackBarBehavior.fixed, width: null);
  }
  return (behavior: SnackBarBehavior.floating, width: 480);
}

class _SideBySideLayout extends StatelessWidget {
  const _SideBySideLayout({
    required this.margin,
    required this.showPane,
    required this.player,
    required this.pane,
  });

  /// Supporting pane share and bounds on expanded windows.
  static const _paneFraction = 0.3;
  static const _minPaneWidth = 280.0;
  static const _maxPaneWidth = 420.0;

  final double margin;
  final bool showPane;
  final Widget player;
  final Widget pane;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final paneWidth = (constraints.maxWidth * _paneFraction).clamp(
          _minPaneWidth,
          _maxPaneWidth,
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(margin, 8, margin, margin),
                child: player,
              ),
            ),
            if (showPane) ...[
              const VerticalDivider(width: 1),
              SizedBox(
                key: PlayerPage.episodesPaneKey,
                width: paneWidth,
                child: pane,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StackedLayout extends StatelessWidget {
  const _StackedLayout({
    required this.margin,
    required this.player,
    required this.episodes,
  });

  final double margin;
  final Widget player;
  final Widget? episodes;

  @override
  Widget build(BuildContext context) {
    final episodes = this.episodes;
    final framedPlayer = Padding(
      padding: EdgeInsets.fromLTRB(margin, 8, margin, 16),
      child: player,
    );
    if (episodes == null) return framedPlayer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(margin, 8, margin, 16),
          child: AspectRatio(aspectRatio: 16 / 9, child: player),
        ),
        const Divider(height: 1),
        Expanded(
          child: KeyedSubtree(key: PlayerPage.episodesPaneKey, child: episodes),
        ),
      ],
    );
  }
}

class _EpisodesPane extends StatelessWidget {
  const _EpisodesPane({required this.source});

  final AnimePlayerSource source;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final torrentKey = source.torrentKey;
    final progress = torrentKey == null
        ? const <int, WatchProgress>{}
        : progressByFile(context.watchWatchProgress(), torrentKey);

    // Shown and hidden only by the app bar toggle; one control per action.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Text(
            l10n.playerEpisodesTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: PlayerEpisodesList(
            files: source.files,
            currentFileIndex: source.fileIndex,
            progressByFile: progress,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            onSelected: context.read<PlayerCubit>().playFile,
          ),
        ),
      ],
    );
  }
}
