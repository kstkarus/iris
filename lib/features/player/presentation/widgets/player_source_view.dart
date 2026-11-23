import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/presentation/widgets/download_selection_footer.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/listed_episodes.dart';
import 'package:iris/features/player/domain/player_continue_target.dart';
import 'package:iris/features/player/domain/player_episode_names.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/widgets/player_episodes_list.dart';
import 'package:iris/features/player/presentation/widgets/player_episode_grid.dart';
import 'package:iris/features/player/presentation/widgets/player_source_download_controls.dart';
import 'package:iris/features/player/presentation/widgets/player_source_download_status.dart';
import 'package:iris/features/player/presentation/widgets/single_file_release_card.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/haptics/app_haptics.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';
import 'package:iris/shared/widgets/status_views.dart';

class PlayerSourceView extends StatelessWidget {
  const PlayerSourceView({
    required this.onFileSelected,
    this.progressByFile = const {},
    this.listedEpisodes = 0,
    this.isOnline = false,
    this.onOpenDownloads,
    super.key,
  });

  static const continueButtonKey = Key('player_source_continue_button');

  final ValueChanged<PlayerVideoFile> onFileSelected;
  final VoidCallback? onOpenDownloads;

  /// Watch progress of this torrent's files, keyed by file index.
  final Map<int, WatchProgress> progressByFile;

  /// Episodes of the anime the user's Shikimori list counts as watched.
  final int listedEpisodes;

  /// An online release, whose episodes come from a server, not a torrent.
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerSourceCubit, PlayerSourceState>(
      builder: (context, state) {
        final (Object key, Widget view) = switch (state) {
          PlayerSourceInitial() || PlayerSourceLoading() => (
            'loading',
            LoadingView(
              semanticsLabel: isOnline
                  ? AppLocalizations.of(context).playerSourceEpisodesPreparing
                  : AppLocalizations.of(context).playerSourcePreparing,
            ),
          ),
          final PlayerSourceReady ready => (
            'ready',
            _SuccessState(
              state: ready,
              progressByFile: progressByFile,
              listed: filesCountedInList(ready.files, listedEpisodes),
              isOnline: isOnline,
              onFileSelected: onFileSelected,
              onOpenDownloads: onOpenDownloads,
            ),
          ),
          PlayerSourceFailure(:final type) => (
            'failure',
            _FailureState(type: type),
          ),
        };
        return DitherSwitcher(
          expand: true,
          duration: const Duration(milliseconds: 320),
          child: KeyedSubtree(key: ValueKey(key), child: view),
        );
      },
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({
    required this.state,
    required this.progressByFile,
    required this.listed,
    required this.onFileSelected,
    required this.onOpenDownloads,
    required this.isOnline,
  });

  final PlayerSourceReady state;
  final Map<int, WatchProgress> progressByFile;
  final Set<int> listed;
  final ValueChanged<PlayerVideoFile> onFileSelected;
  final VoidCallback? onOpenDownloads;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final files = state.files;
    if (files.length == 1) {
      final index = files.single.index;
      return SingleFileReleaseCard(
        state: state,
        progress: progressByFile[index],
        listed: listed.contains(index),
        onPlay: onFileSelected,
        onOpenDownloads: onOpenDownloads,
      );
    }

    final cubit = context.read<PlayerSourceCubit>();
    final target = continueTarget(files, progressByFile, listed: listed);
    final expanded = WindowSizeClass.of(
      context,
    ).isAtLeast(WindowSizeClass.expanded);
    final selecting = state.selecting;
    final scheme = Theme.of(context).colorScheme;
    void onSelected(PlayerVideoFile file) {
      if (cubit.state case PlayerSourceReady(selecting: true)) {
        final before = cubit.state;
        cubit.toggleSelection(file.index);
        if (cubit.state != before) AppHaptics.selection();
      } else {
        onFileSelected(file);
      }
    }

    void onLongPressed(PlayerVideoFile file) {
      final before = cubit.state;
      cubit.startSelection(index: file.index);
      if (cubit.state != before) AppHaptics.medium();
    }

    final Widget topHeader = selecting
        ? expanded
              ? Column(
                  key: const ValueKey('selection_toolbar'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SelectionToolbar(
                      state: state,
                      isOnline: isOnline,
                      progressByFile: progressByFile,
                      listed: listed,
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: DetailLayout.ruleColor(scheme),
                    ),
                    const SizedBox(height: 16),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('no_header'))
        : target != null
        ? Padding(
            key: const ValueKey('continue_card'),
            padding: const EdgeInsets.only(bottom: 16),
            child: _ContinueCard(
              file: target.file,
              number: episodeNumberLabel(
                target.file,
                files.indexOf(target.file),
              ),
              progress: target.isNext
                  ? null
                  : progressByFile[target.file.index],
              isNext: target.isNext,
              downloaded:
                  state.downloadFor(target.file.index)?.status ==
                  DownloadStatus.completed,
              onPressed: () => onFileSelected(target.file),
            ),
          )
        : const SizedBox.shrink(key: ValueKey('no_header'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DitherSwitcher(
          collapse: true,
          resizeDuration: const Duration(milliseconds: 200),
          duration: const Duration(milliseconds: 200),
          child: topHeader,
        ),
        Expanded(
          child: hasEpisodeTitles(files)
              ? PlayerEpisodesList(
                  source: state,
                  progressByFile: progressByFile,
                  listed: listed,
                  isOnline: isOnline,
                  onSelected: onSelected,
                  onLongPressed: onLongPressed,
                )
              : PlayerEpisodeGrid(
                  source: state,
                  highlightedFileIndex: target?.file.index,
                  progressByFile: progressByFile,
                  listed: listed,
                  isOnline: isOnline,
                  onSelected: onSelected,
                  onLongPressed: onLongPressed,
                ),
        ),
        if (!expanded)
          DownloadSelectionFooter(
            visible: selecting,
            child: ReleaseDownloadActions(state: state, isOnline: isOnline),
          ),
      ],
    );
  }
}

class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
    required this.state,
    required this.isOnline,
    required this.progressByFile,
    required this.listed,
  });

  final PlayerSourceReady state;
  final bool isOnline;
  final Map<int, WatchProgress> progressByFile;
  final Set<int> listed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final label = state.selected.isEmpty
        ? downloadSelectionPrompt(l10n, isOnline)
        : l10n.playerSourceSelectedCount(state.selected.length);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w500,
    );
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: MixedDataText(
                  label,
                  sansStyle: style?.copyWith(fontFamily: DetailLayout.sansFont),
                  monoStyle: DetailLayout.monoTelemetryStyle(style),
                ),
              ),
              const SizedBox(width: 16),
              DownloadPresetsMenu(
                state: state,
                isOnline: isOnline,
                progressByFile: progressByFile,
                listed: listed,
                outlined: true,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ReleaseDownloadActions(
            state: state,
            isOnline: isOnline,
            inline: true,
          ),
        ),
      ],
    );
  }
}

/// The file to go on with, set like a row of the list below it, with the
/// action itself as the only verb.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.file,
    required this.number,
    required this.progress,
    required this.isNext,
    required this.downloaded,
    required this.onPressed,
  });

  final PlayerVideoFile file;

  /// As the list shows it: "04", "12.5".
  final String number;

  /// Where the file stopped; null for the next, unwatched file.
  final WatchProgress? progress;
  final bool isNext;
  final bool downloaded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = this.progress;
    final showName = !nameIsJustNumber(file.displayName, this.number);
    final facts = [
      if (progress != null) releaseWatchPosition(l10n, progress),
      if (downloaded) l10n.playerSourceDownloaded,
    ];
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showName)
          Text(
            file.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: DetailLayout.sansFont,
              fontWeight: FontWeight.w500,
              fontSize: 15,
              height: 1.3,
            ),
          ),
        // The file's own row below carries the bar.
        if (facts.isNotEmpty) ...[
          if (showName) const SizedBox(height: 5),
          PixelSeparatedText.parts(
            facts,
            cleanLineWrap: true,
            sansStyle: theme.textTheme.bodySmall?.copyWith(
              fontFamily: DetailLayout.sansFont,
              color: scheme.onSurfaceVariant,
            ),
            monoStyle: DetailLayout.monoTelemetryStyle(
              theme.textTheme.bodySmall,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    final button = FilledButton(
      key: PlayerSourceView.continueButtonKey,
      onPressed: onPressed,
      child: Text(
        isNext
            ? l10n.watchProgressPlayNextButton
            : l10n.watchProgressContinueButton,
      ),
    );
    final number = SizedBox.square(
      dimension: 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          border: Border.all(
            color: progress != null
                ? scheme.tertiary
                : DetailLayout.ruleColor(scheme),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                this.number,
                style: DetailLayout.monoTelemetryStyle(
                  theme.textTheme.titleMedium,
                  fontWeight: FontWeight.w600,
                  color: progress != null ? scheme.tertiary : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: DetailLayout.ruleColor(scheme)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: !WindowSizeClass.of(context).isAtLeast(WindowSizeClass.expanded)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      number,
                      const SizedBox(width: 12),
                      Expanded(child: details),
                    ],
                  ),
                  const SizedBox(height: 14),
                  button,
                ],
              )
            : Row(
                children: [
                  number,
                  const SizedBox(width: 12),
                  Expanded(child: details),
                  const SizedBox(width: 16),
                  button,
                ],
              ),
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.type});

  final PlayerSourceFailureType type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = type == PlayerSourceFailureType.unsupportedSource
        ? l10n.playerSourceUnsupported
        : l10n.playerSourceUnableToPrepare;

    return RetryView(
      message: message,
      onRetry: () => context.read<PlayerSourceCubit>().loadSource(),
    );
  }
}
