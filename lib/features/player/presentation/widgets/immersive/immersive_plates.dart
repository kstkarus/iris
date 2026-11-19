part of '../player_immersive_controls.dart';

/// Sits where the play button is; the startup label goes below it, with
/// the torrent's numbers if the start drags on.
class _BufferingSpinner extends StatelessWidget {
  const _BufferingSpinner({
    required this.engine,
    required this.color,
    required this.startupLabel,
    required this.playBox,
  });

  final MediaKitPlayerEngine engine;
  final Color color;
  final String? startupLabel;

  /// The play button's size, whose place the spinner takes.
  final double playBox;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: Listenable.merge([engine.buffering, engine.phase]),
        builder: (context, _) {
          final label = startupLabel;
          final rebuffering =
              engine.buffering.value &&
              engine.phase.value == PlayerEnginePhase.ready;
          if (label == null && !rebuffering) return const SizedBox.shrink();
          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: label == null
                    ? TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: motionDuration(
                          context,
                          const Duration(milliseconds: 180),
                        ),
                        builder: (context, value, child) =>
                            Opacity(opacity: value, child: child),
                        child: BlockRunner(
                          key: const Key('player_buffering_spinner'),
                          color: color,
                          trackColor: Colors.white24,
                        ),
                      )
                    : BlockRunner(
                        key: const Key('player_buffering_spinner'),
                        color: color,
                        trackColor: Colors.white24,
                      ),
              ),
              if (label != null)
                Center(
                  child: Padding(
                    // Below the play button's place.
                    padding: EdgeInsets.only(top: playBox + 52),
                    child: PlayerWaitLabel(
                      label: label,
                      stats: engine.playbackStats,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

const _plateMinHeight = 48.0;
const _offerPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 8);

const _offerShape = RoundedRectangleBorder();

/// Secondary buttons over the video: dense dark plate with a crisp 1 px border.
ButtonStyle _overVideoButtonStyle(ThemeData theme) {
  return OutlinedButton.styleFrom(
    minimumSize: const Size(64, _plateMinHeight),
    padding: _offerPadding,
    shape: _offerShape,
    foregroundColor: playerPlateText,
    backgroundColor: playerPlateBackground,
    side: const BorderSide(color: playerPlateActionBorder, width: 1),
    textStyle: theme.textTheme.titleSmall?.copyWith(
      fontFamily: DetailLayout.sansFont,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
  );
}

/// The resume message as part of the player rather than an app snackbar.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.accent, super.key});

  final PlayerNotice notice;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motionDuration(context, const Duration(milliseconds: 300)),
      builder: (context, value, child) =>
          DitherTransition.transition(child!, AlwaysStoppedAnimation(value)),
      child: PlayerCountdown(
        duration: notice.timeout,
        onElapsed: notice.onTimeout,
        child: PlayerCountdownBar(
          color: playerPlateSecondary,
          child: DecoratedBox(
            key: const Key('player_notice'),
            decoration: BoxDecoration(
              color: playerPlateBackground,
              border: Border.all(color: playerPlateBorder),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _plateMinHeight),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        notice.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFamily: DetailLayout.sansFont,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: playerPlateText,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 24,
                    child: VerticalDivider(width: 1, color: playerPlateBorder),
                  ),
                  Flexible(
                    child: TextButton(
                      key: const Key('player_notice_action'),
                      onPressed: notice.onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: accent,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(48, 48),
                        textStyle: theme.textTheme.titleSmall?.copyWith(
                          fontFamily: DetailLayout.sansFont,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: Text(
                        notice.actionLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "+85 s" early in a file with no known opening, shown at first and then
/// with the controls, as the other offers.
class _SkipForwardOffer extends StatelessWidget {
  const _SkipForwardOffer({
    required this.engine,
    required this.controlsVisible,
  });

  final MediaKitPlayerEngine engine;
  final ValueListenable<bool> controlsVisible;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seconds = MediaKitPlayerEngine.skipForwardStep.inSeconds;
    return ValueListenableBuilder<bool>(
      valueListenable: engine.skipForwardOffered,
      builder: (context, offered, _) {
        if (!offered) return const SizedBox.shrink();
        return PlayerAutoHidingOffer(
          controlsVisible: controlsVisible,
          running: engine.advancing,
          child: Semantics(
            label: l10n.playerSkipForwardTooltip(seconds),
            child: _OfferButton.outlined(
              key: const Key('player_skip_forward_button'),
              label: l10n.playerSkipForward(seconds),
              onPressed: () => unawaited(engine.skipForward()),
            ),
          ),
        );
      },
    );
  }
}

/// An action offered over the video ("Skip opening"). Its
/// label names the action, so it carries no glyph.
class _OfferButton extends StatelessWidget {
  const _OfferButton.outlined({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = PlayerOfferLabel(label: label, maxWidth: 240);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PlayerCountdownBar(
        color: Colors.white70,
        inset: const EdgeInsets.all(1),
        child: OutlinedButton(
          onPressed: onPressed,
          style: _overVideoButtonStyle(theme),
          child: content,
        ),
      ),
    );
  }
}

class _VolumeHud extends StatelessWidget {
  const _VolumeHud({required this.volume, super.key});

  final double volume;

  @override
  Widget build(BuildContext context) {
    return _HudPlate(
      mono: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelIcon(
            volume <= 0 ? PixelGlyph.volumeOff : PixelGlyph.volumeUp,
            size: 21,
            color: playerPlateText,
          ),
          const SizedBox(width: 10),
          Text('${volume.round()}%'),
        ],
      ),
    );
  }
}

/// The speed while Space is held.
class _FastForwardHud extends StatelessWidget {
  const _FastForwardHud({super.key});

  @override
  Widget build(BuildContext context) {
    return _HudPlate(
      mono: true,
      child: Text(
        AppLocalizations.of(
          context,
        ).playerPlaybackRate(MediaKitPlayerEngine.fastForwardRate),
      ),
    );
  }
}

/// A brief readout over the video of what a key or a gesture just did
/// (the volume, a seek, the speed); it takes no touches.
class _HudPlate extends StatelessWidget {
  const _HudPlate({
    required this.child,
    this.alignment = const Alignment(0, -0.45),
    this.mono = false,
    super.key,
  });

  final Widget child;
  final Alignment alignment;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: motionDuration(context, const Duration(milliseconds: 120)),
          builder: (context, value, child) =>
              Opacity(opacity: value, child: child),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: playerPlateBackground,
              border: Border.all(color: playerPlateBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: DefaultTextStyle.merge(
                style: mono
                    ? DetailLayout.monoTelemetryStyle(
                        const TextStyle(
                          color: playerPlateText,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : const TextStyle(
                        fontFamily: DetailLayout.sansFont,
                        color: playerPlateText,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
