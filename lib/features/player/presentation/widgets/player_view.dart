import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/player/domain/entities/player_launch_failure.dart';
import 'package:iris/features/player/domain/entities/player_launch_progress.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/file_display_name.dart';

class PlayerView extends StatelessWidget {
  const PlayerView({required this.viewportFactory, super.key});

  final PlayerViewportFactory viewportFactory;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerCubit, PlayerState>(
      builder: (context, state) {
        final cubit = context.read<PlayerCubit>();
        return switch (state) {
          PlayerReady() ||
          PlayerPreparing(keepsPlayer: true) => viewportFactory.build(
            engine: cubit.engine,
            next: switch (cubit.source.nextFile) {
              final next? => PlayerNextFile(
                title: fileDisplayName(next.name),
                play: () => cubit.playFile(next),
              ),
              null => null,
            },
          ),
          PlayerInitial() => _LoadingState(
            progress: const PlayerLaunchProgress.initial(),
          ),
          PlayerPreparing(:final progress) => _LoadingState(progress: progress),
          PlayerFailure(:final type) => _FailureState(type: type),
        };
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.progress});

  final PlayerLaunchProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final clampedProgress = progress.bufferProgress.clamp(0.0, 1.0);
    final percent = (clampedProgress * 100).round();
    final message = progress.stage == PlayerLaunchStage.waitingForBuffer
        ? l10n.playerPreparingMoreBuffer
        : l10n.playerPreparing;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            value: clampedProgress > 0 ? clampedProgress : null,
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(l10n.playerStreamPreparationProgress(percent)),
          const SizedBox(height: 4),
          Text(
            l10n.playerStreamPreparationSpeed(
              _formatTransferRate(progress.downloadRateBytesPerSecond),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.type});

  final PlayerLaunchFailure type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = type == PlayerLaunchFailure.unableToPrepareStartupBuffer
        ? l10n.playerUnableToBufferForStart
        : l10n.playerUnableToStart;

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
              onPressed: () => context.read<PlayerCubit>().loadPlayback(),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTransferRate(int bytesPerSecond) {
  const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
  var value = bytesPerSecond.toDouble();
  var unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  final fractionDigits = unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
}
