import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
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
                  title: next.displayName,
                  play: () => cubit.playFile(next),
                ),
                null => null,
              },
            );
          case PlayerInitial() || PlayerPreparing():
            status = const _LoadingState();
          case PlayerFailure():
            status = const _FailureState();
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
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return LoadingView(label: AppLocalizations.of(context).playerPreparing);
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RetryView(
      message: l10n.playerUnableToStart,
      onRetry: () => context.read<PlayerCubit>().loadPlayback(),
    );
  }
}
