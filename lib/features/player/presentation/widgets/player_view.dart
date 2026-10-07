import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/player/domain/entities/player_launch_failure.dart';
import 'package:iris/features/player/domain/entities/player_launch_progress.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/status_views.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

class PlayerView extends StatelessWidget {
  const PlayerView({required this.viewportFactory, this.chrome, super.key});

  final PlayerViewportFactory viewportFactory;

  /// Immersive mode: passed to the viewport, and the loading and failure
  /// states get a way back since there is no app bar.
  final PlayerChrome? chrome;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerCubit, PlayerState>(
      builder: (context, state) {
        final cubit = context.read<PlayerCubit>();
        final Widget status;
        switch (state) {
          case PlayerReady() || PlayerPreparing(keepsPlayer: true):
            return viewportFactory.build(
              engine: cubit.engine,
              chrome: chrome,
              next: switch (cubit.source.nextFile) {
                final next? => PlayerNextFile(
                  title: fileDisplayName(next.name),
                  play: () => cubit.playFile(next),
                ),
                null => null,
              },
            );
          case PlayerInitial():
            status = _LoadingState(
              progress: const PlayerLaunchProgress.initial(),
            );
          case PlayerPreparing(:final progress):
            status = _LoadingState(progress: progress);
          case PlayerFailure(:final type):
            status = _FailureState(type: type);
        }
        final immersive = chrome;
        if (immersive == null) return status;
        return Stack(
          fit: StackFit.expand,
          children: [
            status,
            Positioned(
              left: 24,
              top: 20,
              child: IconButton(
                key: const Key('player_back_button'),
                tooltip: AppLocalizations.of(context).playerBack,
                iconSize: 28,
                icon: const PixelIcon(PixelGlyph.arrowLeft),
                onPressed: immersive.onBack,
              ),
            ),
          ],
        );
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

    return LoadingView(
      label: message,
      value: clampedProgress > 0 ? clampedProgress : null,
      details: [
        l10n.playerStreamPreparationProgress(percent),
        l10n.playerStreamPreparationSpeed(
          _formatTransferRate(progress.downloadRateBytesPerSecond),
        ),
      ],
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

    return MessageView(
      message: message,
      action: FilledButton(
        onPressed: () => context.read<PlayerCubit>().loadPlayback(),
        child: Text(l10n.commonRetry),
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
