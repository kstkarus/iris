import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/status_views.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

class PlayerView extends StatelessWidget {
  const PlayerView({
    required this.viewportFactory,
    required this.chrome,
    this.input = PlayerInputMode.pointer,
    super.key,
  });

  final PlayerViewportFactory viewportFactory;

  /// Passed to the viewport; the loading and failure states take its way
  /// back, as the page has no app bar.
  final PlayerChrome chrome;
  final PlayerInputMode input;

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
              input: input,
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
        // Clear of a camera cutout at the side of a phone in landscape.
        final safe = MediaQuery.paddingOf(context);
        return Stack(
          fit: StackFit.expand,
          children: [
            status,
            Positioned(
              left: 24 + safe.left,
              top: 20 + safe.top,
              child: IconButton(
                key: const Key('player_back_button'),
                tooltip: AppLocalizations.of(context).playerBack,
                iconSize: 28,
                icon: const PixelIcon(PixelGlyph.arrowLeft),
                onPressed: chrome.onBack,
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
