import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/widgets/player_episodes_list.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/file_display_name.dart';

class PlayerSourceView extends StatelessWidget {
  const PlayerSourceView({
    required this.onFileSelected,
    this.progressByFile = const {},
    super.key,
  });

  static const continueButtonKey = Key('player_source_continue_button');

  final ValueChanged<PlayerVideoFile> onFileSelected;

  /// Watch progress of this torrent's files, keyed by file index.
  final Map<int, WatchProgress> progressByFile;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerSourceCubit, PlayerSourceState>(
      builder: (context, state) {
        return switch (state) {
          PlayerSourceInitial() || PlayerSourceLoading() => _LoadingState(
            message: AppLocalizations.of(context).playerSourcePreparing,
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

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
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

  /// The file to continue with: the last one watched, or the one after it
  /// when that was finished.
  ({PlayerVideoFile file, bool isNext})? _continueTarget() {
    WatchProgress? latest;
    for (final progress in progressByFile.values) {
      if (latest == null || progress.updatedAt.isAfter(latest.updatedAt)) {
        latest = progress;
      }
    }
    if (latest == null) return null;
    final position = files.indexWhere(
      (file) => file.index == latest!.fileIndex,
    );
    if (position < 0) return null;
    if (!latest.isFinished) return (file: files[position], isNext: false);
    if (position + 1 >= files.length) return null;
    return (file: files[position + 1], isNext: true);
  }

  @override
  Widget build(BuildContext context) {
    final continueTarget = files.length > 1 ? _continueTarget() : null;
    // Text rows instead of a card and a button per file: the whole row
    // starts the file, so 24 episodes stay scannable.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (continueTarget != null) ...[
          _ContinueCard(
            file: continueTarget.file,
            isNext: continueTarget.isNext,
            onPressed: () => onFileSelected(continueTarget.file),
          ),
          const SizedBox(height: 8),
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

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.file,
    required this.isNext,
    required this.onPressed,
  });

  final PlayerVideoFile file;
  final bool isNext;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isNext ? Icons.skip_next : Icons.play_circle_outline,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isNext
                    ? l10n.watchProgressNextFile(fileDisplayName(file.name))
                    : l10n.watchProgressContinueFile(
                        fileDisplayName(file.name),
                      ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: PlayerSourceView.continueButtonKey,
              onPressed: onPressed,
              child: Text(
                isNext
                    ? l10n.watchProgressPlayNextButton
                    : l10n.watchProgressContinueButton,
              ),
            ),
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.read<PlayerSourceCubit>().loadSource(),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
