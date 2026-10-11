import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/player_continue_target.dart';
import 'package:iris/features/player/domain/player_episode_names.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/widgets/player_episodes_list.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_line.dart';
import 'package:iris/shared/widgets/status_views.dart';

class PlayerSourceView extends StatelessWidget {
  const PlayerSourceView({
    required this.onFileSelected,
    this.progressByFile = const {},
    this.isOnline = false,
    super.key,
  });

  static const continueButtonKey = Key('player_source_continue_button');

  final ValueChanged<PlayerVideoFile> onFileSelected;

  /// Watch progress of this torrent's files, keyed by file index.
  final Map<int, WatchProgress> progressByFile;

  /// An online release, whose episodes come from a server, not a torrent.
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerSourceCubit, PlayerSourceState>(
      builder: (context, state) {
        return switch (state) {
          PlayerSourceInitial() || PlayerSourceLoading() => LoadingView(
            label: isOnline
                ? AppLocalizations.of(context).playerSourceEpisodesPreparing
                : AppLocalizations.of(context).playerSourcePreparing,
          ),
          PlayerSourceReady(:final preparedSource) => _SuccessState(
            files: preparedSource.files,
            progressByFile: progressByFile,
            onFileSelected: onFileSelected,
          ),
          PlayerSourceFailure(:final type) => _FailureState(type: type),
        };
      },
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({
    required this.files,
    required this.progressByFile,
    required this.onFileSelected,
  });

  final List<PlayerVideoFile> files;
  final Map<int, WatchProgress> progressByFile;
  final ValueChanged<PlayerVideoFile> onFileSelected;

  @override
  Widget build(BuildContext context) {
    final target = files.length > 1
        ? continueTarget(files, progressByFile)
        : null;
    // Text rows instead of a card and a button per file: the whole row
    // starts the file, so 24 episodes stay scannable.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (target != null) ...[
          _ContinueCard(
            file: target.file,
            number: episodeNumberLabel(target.file, files.indexOf(target.file)),
            progress: target.isNext ? null : progressByFile[target.file.index],
            isNext: target.isNext,
            onPressed: () => onFileSelected(target.file),
          ),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: PlayerEpisodesList(
            files: files,
            currentFileIndex: null,
            progressByFile: progressByFile,
            onSelected: onFileSelected,
            showSizes: true,
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
    required this.onPressed,
  });

  final PlayerVideoFile file;

  /// As the list shows it: "04", "12.5".
  final String number;

  /// Where the file stopped; null for the next, unwatched file.
  final WatchProgress? progress;
  final bool isNext;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final progress = this.progress;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          file.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        // The file's own row below carries the bar.
        if (progress != null) ...[
          const SizedBox(height: 4),
          WatchProgressLine(progress: progress, showBar: false),
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
    final number = SizedBox(
      width: 44,
      child: Text(this.number, style: theme.textTheme.titleMedium),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: LayoutBuilder(
          // Narrow cards put the button under the text, so neither the
          // name nor the position gets cut short.
          builder: (context, constraints) => constraints.maxWidth < 480
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        number,
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
                    Expanded(child: details),
                    const SizedBox(width: 16),
                    button,
                  ],
                ),
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
