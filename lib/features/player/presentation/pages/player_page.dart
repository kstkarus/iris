import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/listed_episodes.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/presentation/cubit/episode_mark_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';
import 'package:iris/features/player/presentation/models/player_chrome_mapper.dart';
import 'package:iris/features/player/presentation/widgets/player_episode_cards.dart';
import 'package:iris/features/player/presentation/widgets/player_view.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/utils/desktop_platform.dart';
import 'package:iris/shared/theme/over_video_theme.dart';
import 'package:iris/shared/window/player_screen_mode.dart';

/// The video fills the screen, with streaming-app controls over it and the
/// episodes in a drawer; messages (the resume, the Shikimori mark) show
/// inside the player. Phones and tablets play in landscape with the system
/// bars hidden ([screenMode]) and get controls sized for touch.
class PlayerPage extends StatefulWidget {
  const PlayerPage({
    required this.viewportFactory,
    this.screenMode = const NoPlayerScreenMode(),
    super.key,
  });

  final PlayerViewportFactory viewportFactory;
  final PlayerScreenMode screenMode;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  /// Puts the screen back in the player's mode when the app returns to it.
  late final AppLifecycleListener _lifecycle;

  /// The resume message.
  PlayerNotice? _notice;

  /// What became of the episode in the Shikimori list; the resume message
  /// goes first.
  PlayerNotice? _markNotice;

  @override
  void initState() {
    super.initState();
    unawaited(widget.screenMode.enter());
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(widget.screenMode.enter()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(widget.screenMode.leave());
    super.dispose();
  }

  void _hideNotice() {
    if (mounted && _notice != null) setState(() => _notice = null);
  }

  @override
  Widget build(BuildContext context) {
    final page = PopScope(
      // The page below turns back while this one goes, not after.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(widget.screenMode.leave());
      },
      child: _buildPlayer(context),
    );
    // Pages opened without a list to mark (as in tests) only play.
    final marks = context.read<EpisodeMarkCubit?>();
    if (marks == null) return page;
    return MultiBlocListener(
      listeners: [
        BlocListener<PlayerCubit, PlayerState>(
          listenWhen: (previous, current) =>
              current is PlayerReady &&
              current.watched &&
              !(previous is PlayerReady && previous.watched),
          listener: (context, state) =>
              marks.watched(context.read<PlayerCubit>().source),
        ),
        BlocListener<EpisodeMarkCubit, EpisodeMarkState>(
          bloc: marks,
          listener: _showMarkNotice,
        ),
      ],
      child: page,
    );
  }

  Widget _buildPlayer(BuildContext context) {
    return Theme(
      data: OverVideoTheme.of(Theme.of(context)),
      child: BlocConsumer<PlayerCubit, PlayerState>(
        listener: _showPlaybackMessages,
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: PlayerView(
              viewportFactory: widget.viewportFactory,
              chrome: _chrome(context),
              input: isDesktopPlatform
                  ? PlayerInputMode.pointer
                  : PlayerInputMode.touch,
            ),
          );
        },
      ),
    );
  }

  PlayerChrome _chrome(BuildContext context) {
    final cubit = context.read<PlayerCubit>();
    final source = cubit.source;
    return playerChromeFor(
      AppLocalizations.of(context),
      source,
      onBack: () => Navigator.of(context).maybePop(),
      notice: _notice ?? _markNotice,
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
  /// offered inside the player when a file ends.
  void _showPlaybackMessages(BuildContext context, PlayerState state) {
    final cubit = context.read<PlayerCubit>();
    if (state is! PlayerReady ||
        !state.showResumeNotice ||
        state.startPosition == null) {
      _hideNotice();
      return;
    }

    final choice = resumeChoice(AppLocalizations.of(context), cubit, state);
    setState(
      () => _notice = PlayerNotice(
        message: choice.message,
        actionLabel: choice.actionLabel,
        onAction: choice.onAction,
        timeout: state.started ? resumeNoticeDuration : null,
        onTimeout: cubit.dismissResumeNotice,
      ),
    );
  }

  /// What became of the watched episode in the Shikimori list: marked (with
  /// undo), offered when its number is a guess, or failed (with retry).
  void _showMarkNotice(BuildContext context, EpisodeMarkState state) {
    final l10n = AppLocalizations.of(context);
    final marks = context.read<EpisodeMarkCubit>();
    final notice = switch (state) {
      EpisodeMarkOffered(:final episode) => (
        message: l10n.playerMarkOffer(episode),
        actionLabel: l10n.playerMarkAction,
        onAction: marks.confirm,
        timeout: markOfferDuration,
      ),
      EpisodeMarkDone(:final episode) => (
        message: l10n.playerMarked(episode),
        actionLabel: l10n.commonUndo,
        onAction: () => unawaited(marks.undo()),
        timeout: markNoticeDuration,
      ),
      EpisodeMarkFailed() => (
        message: l10n.playerMarkFailed,
        actionLabel: l10n.commonRetry,
        onAction: marks.confirm,
        timeout: markNoticeDuration,
      ),
      EpisodeMarkIdle() || EpisodeMarkSaving() => null,
    };

    setState(
      () => _markNotice = notice == null
          ? null
          : PlayerNotice(
              message: notice.message,
              actionLabel: notice.actionLabel,
              onAction: notice.onAction,
              timeout: notice.timeout,
              onTimeout: marks.dismiss,
            ),
    );
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

/// How long the Shikimori mark notice stays; an offer stays longer, as it
/// asks for something.
const markNoticeDuration = Duration(seconds: 8);
const markOfferDuration = Duration(seconds: 15);

/// How long the resume notice stays once the file plays; until then it
/// stays, so the choice it offers is there for the whole startup.
const resumeNoticeDuration = Duration(seconds: 8);

class _EpisodeCardsPane extends StatelessWidget {
  const _EpisodeCardsPane({required this.source, required this.onSelected});

  final AnimePlayerSource source;
  final ValueChanged<PlayerVideoFile> onSelected;

  @override
  Widget build(BuildContext context) {
    final progress = _sourceProgress(context, source);
    return PlayerEpisodeCards(
      files: source.files,
      currentFileIndex: source.fileIndex,
      progressByFile: progress,
      listed: filesCountedInList(source.files, source.listedEpisodes),
      onSelected: onSelected,
    );
  }
}

/// Watch progress of [source]'s files, keyed by file index.
Map<int, WatchProgress> _sourceProgress(
  BuildContext context,
  AnimePlayerSource source,
) {
  final torrentKey = source.torrentKey;
  return torrentKey == null
      ? const {}
      : progressByFile(context.watchWatchProgress(), torrentKey);
}
