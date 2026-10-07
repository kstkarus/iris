import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';
import 'package:iris/features/player/presentation/widgets/player_adaptive_layout.dart';
import 'package:iris/features/player/presentation/widgets/player_episode_cards.dart';
import 'package:iris/features/player/presentation/widgets/player_episodes_list.dart';
import 'package:iris/features/player/presentation/widgets/player_view.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/utils/episode_number.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/theme/over_video_theme.dart';
import 'package:iris/shared/utils/release_title.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/page_title.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

/// Video with the torrent's episodes as a supporting pane: beside the video
/// on expanded and landscape windows (about 70/30, can be hidden), below it
/// on portrait ones.
///
/// On desktop the video fills the window instead, with streaming-app
/// controls over it and the episodes in a drawer.
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

  /// The immersive player's own resume message, instead of a snackbar.
  PlayerNotice? _notice;

  /// Counts the notice down once the file plays; until then it stays, so
  /// the choice it offers is there for the whole startup.
  Timer? _noticeTimer;

  static const _noticeDuration = Duration(seconds: 8);

  @override
  void dispose() {
    _closePlaybackSnackBar();
    _noticeTimer?.cancel();
    super.dispose();
  }

  void _hideNotice() {
    _noticeTimer?.cancel();
    _noticeTimer = null;
    if (mounted && _notice != null) setState(() => _notice = null);
  }

  void _closePlaybackSnackBar() {
    // Cleared first, so the closed callback knows the page closed it.
    final controller = _playbackSnackBar;
    _playbackSnackBar = null;
    controller?.close();
  }

  void _showResumeSnackBar(BuildContext context, PlayerCubit cubit) {
    _closePlaybackSnackBar();
    final behavior = _snackBarPlacement(context);
    // One snackbar at a time: this replaces whatever is showing instead of
    // queueing behind it.
    final controller = (ScaffoldMessenger.of(context)..hideCurrentSnackBar())
        .showSnackBar(
          SnackBar(
            key: const Key('player_resume_snackbar'),
            content: _ResumeSnackBarContent(cubit: cubit),
            // Closed by the page: it waits for the file to start, then
            // counts down like the immersive notice.
            duration: const Duration(days: 1),
            behavior: behavior.behavior,
            width: behavior.width,
          ),
        );
    _playbackSnackBar = controller;
    controller.closed.then((_) {
      if (!identical(_playbackSnackBar, controller)) return;
      // Swiped away by the viewer.
      _playbackSnackBar = null;
      cubit.dismissResumeNotice();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<PlayerCubit>();

    if (isDesktopPlayerPlatform()) return _buildImmersive(context);

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
                      icon: const PixelIcon(PixelGlyph.episodes, size: 21),
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

  Widget _buildImmersive(BuildContext context) {
    return Theme(
      data: immersivePlayerTheme(Theme.of(context)),
      child: BlocConsumer<PlayerCubit, PlayerState>(
        listener: _showPlaybackMessages,
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: PlayerView(
              key: _playerKey,
              viewportFactory: widget.viewportFactory,
              chrome: _immersiveChrome(context),
            ),
          );
        },
      ),
    );
  }

  PlayerChrome _immersiveChrome(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<PlayerCubit>();
    final source = cubit.source;
    final release = source.sourceTitle.trim();
    final anime = source.animeTitle.trim();
    // Saved torrents carry their release name as the anime title too.
    final overline = anime.isNotEmpty && anime != release
        ? anime
        : releaseDisplayTitle(release);
    final episode = episodeNumberFromFileName(source.fileName);
    final count = source.files.length;
    final position = source.files.indexWhere(
      (file) => file.index == source.fileIndex,
    );
    final inRelease = count > 1 && position >= 0;
    // Where the episode number is the file's place, the place adds only
    // the total: "Episode 20 of 37" instead of a line repeating the 20.
    final placeIsNumber = inRelease && episode == position + 1;
    final details = inRelease && !placeIsNumber
        ? l10n.playerEpisodePosition(position + 1, count)
        : null;
    final episodesCaption = [
      if (release.isNotEmpty) release,
      l10n.animeEpisodeCount('$count', count),
    ].join(' · ');

    return PlayerChrome(
      title: episode == null
          ? fileDisplayName(source.fileName)
          : l10n.playerEpisodeNumber(episode),
      titleDetail: placeIsNumber ? l10n.playerEpisodeOfTotal(count) : null,
      overline: overline,
      details: details,
      episodesCaption: episodesCaption,
      onBack: () => Navigator.of(context).maybePop(),
      notice: _notice,
      episodes: source.files.length > 1
          ? (context, close) => _EpisodeCardsPane(
              source: source,
              onSelected: (file) {
                close();
                cubit.playFile(file);
              },
            )
          : null,
    );
  }

  /// The automatic resume, with "Start over"; it does not interrupt
  /// playback. It stays while the file starts, saying where playback will
  /// pick up, and counts down once the file plays. The next file is
  /// offered inside the player (also in full screen) when a file ends.
  void _showPlaybackMessages(BuildContext context, PlayerState state) {
    final cubit = context.read<PlayerCubit>();
    if (state is! PlayerReady ||
        !state.showResumeNotice ||
        state.startPosition == null) {
      _closePlaybackSnackBar();
      _hideNotice();
      return;
    }

    if (state.started) {
      _noticeTimer ??= Timer(_noticeDuration, cubit.dismissResumeNotice);
    }
    if (isDesktopPlayerPlatform()) {
      final choice = resumeChoice(AppLocalizations.of(context), cubit, state);
      setState(
        () => _notice = PlayerNotice(
          message: choice.message,
          actionLabel: choice.actionLabel,
          onAction: choice.onAction,
        ),
      );
    } else if (_playbackSnackBar == null) {
      _showResumeSnackBar(context, cubit);
    }
  }
}

/// What the resume notice says for [state] and what its action does:
/// where playback picks up (or will, while the file starts), and the other
/// choice.
@visibleForTesting
({String message, String actionLabel, VoidCallback onAction}) resumeChoice(
  AppLocalizations l10n,
  PlayerCubit cubit,
  PlayerReady state,
) {
  final position = formatPlaybackPosition(state.startPosition!);
  if (state.startsOver) {
    return (
      message: state.started ? l10n.playerStartedOver : l10n.playerStartingOver,
      actionLabel: l10n.playerResumeFromAction(position),
      onAction: cubit.resumeSavedPosition,
    );
  }
  return (
    message: state.started
        ? l10n.playerResumedFrom(position)
        : l10n.playerResumingFrom(position),
    actionLabel: l10n.playerStartOver,
    onAction: cubit.restartFromBeginning,
  );
}

/// The resume notice as a snackbar, kept current with the player's state.
class _ResumeSnackBarContent extends StatelessWidget {
  const _ResumeSnackBarContent({required this.cubit});

  final PlayerCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final actionColor =
        theme.snackBarTheme.actionTextColor ?? theme.colorScheme.inversePrimary;
    return BlocBuilder<PlayerCubit, PlayerState>(
      bloc: cubit,
      builder: (context, state) {
        if (state is! PlayerReady || state.startPosition == null) {
          return const SizedBox.shrink();
        }
        final choice = resumeChoice(l10n, cubit, state);
        return Row(
          children: [
            Expanded(child: Text(choice.message)),
            const SizedBox(width: 8),
            TextButton(
              key: const Key('player_resume_action'),
              onPressed: choice.onAction,
              style: TextButton.styleFrom(foregroundColor: actionColor),
              child: Text(choice.actionLabel),
            ),
          ],
        );
      },
    );
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

/// The app's colours as they read over video: its dark theme, so dialogs
/// and progress opened from the player match it.
ThemeData immersivePlayerTheme(ThemeData base) => OverVideoTheme.of(base);

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

class _EpisodeCardsPane extends StatelessWidget {
  const _EpisodeCardsPane({required this.source, required this.onSelected});

  final AnimePlayerSource source;
  final ValueChanged<PlayerVideoFile> onSelected;

  @override
  Widget build(BuildContext context) {
    final torrentKey = source.torrentKey;
    final progress = torrentKey == null
        ? const <int, WatchProgress>{}
        : progressByFile(context.watchWatchProgress(), torrentKey);
    return PlayerEpisodeCards(
      files: source.files,
      currentFileIndex: source.fileIndex,
      progressByFile: progress,
      onSelected: onSelected,
    );
  }
}
