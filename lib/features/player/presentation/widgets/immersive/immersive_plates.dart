part of '../player_immersive_controls.dart';

/// Sits where the play button is, so it lines up with ±10 s; the startup
/// label goes below it, with the torrent's numbers if the start drags on.
class _BufferingSpinner extends StatelessWidget {
  const _BufferingSpinner({
    required this.engine,
    required this.color,
    required this.startupLabel,
  });

  final MediaKitPlayerEngine engine;
  final Color color;
  final String? startupLabel;

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
                child: BlockRunner(
                  key: const Key('player_buffering_spinner'),
                  color: color,
                  trackColor: Colors.white24,
                ),
              ),
              if (label != null)
                Center(
                  child: Padding(
                    // Below the 96 px play button's place.
                    padding: const EdgeInsets.only(top: 148),
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

const _overVideoOutlineWidth = 1.5;

/// Room inside the buttons offered over the video; square, as the app is.
const _offerPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);

const _offerShape = RoundedRectangleBorder();

/// Secondary buttons over the video: a dark glass with a light outline.
ButtonStyle _overVideoButtonStyle(ThemeData theme) {
  return OutlinedButton.styleFrom(
    padding: _offerPadding,
    shape: _offerShape,
    foregroundColor: Colors.white,
    backgroundColor: Colors.black54,
    side: const BorderSide(
      color: Colors.white70,
      width: _overVideoOutlineWidth,
    ),
    textStyle: theme.textTheme.titleSmall,
  );
}

/// The resume message as part of the player rather than an app snackbar.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.accent});

  final PlayerNotice notice;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: PlayerCountdown(
        duration: notice.timeout,
        onElapsed: notice.onTimeout,
        child: PlayerCountdownBar(
          color: Colors.white70,
          inset: const EdgeInsets.all(1),
          child: DecoratedBox(
            key: const Key('player_notice'),
            decoration: BoxDecoration(
              color: Colors.black54,
              border: Border.all(color: Colors.white24),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 6, 8, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notice.message,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    key: const Key('player_notice_action'),
                    onPressed: notice.onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      textStyle: theme.textTheme.titleSmall,
                    ),
                    child: Text(notice.actionLabel),
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

/// "+85 s" early in a file with no known opening; part of the controls, so
/// it hides with them.
class _SkipForwardOffer extends StatelessWidget {
  const _SkipForwardOffer({required this.engine, required this.visible});

  final MediaKitPlayerEngine engine;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seconds = MediaKitPlayerEngine.skipForwardStep.inSeconds;
    return ValueListenableBuilder<bool>(
      valueListenable: engine.skipForwardOffered,
      builder: (context, offered, _) {
        if (!offered) return const SizedBox.shrink();
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: _controlsFade,
            child: Semantics(
              label: l10n.playerSkipForwardTooltip(seconds),
              child: _OfferButton.outlined(
                key: const Key('player_skip_forward_button'),
                label: l10n.playerSkipForward(seconds),
                onPressed: () => unawaited(engine.skipForward()),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// An action offered over the video ("Skip opening", "Play next"). Its
/// label names the action, so it carries no glyph.
class _OfferButton extends StatelessWidget {
  const _OfferButton.outlined({
    required this.label,
    required this.onPressed,
    super.key,
  }) : filled = false,
       detail = null;

  const _OfferButton.filled({
    required this.label,
    required this.onPressed,
    this.detail,
    super.key,
  }) : filled = true;

  final bool filled;
  final String label;
  final String? detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = PlayerOfferLabel(
      label: label,
      detail: detail,
      maxWidth: 240,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: filled
          ? PlayerCountdownBar(
              color: theme.colorScheme.onPrimary,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  padding: _offerPadding,
                  shape: _offerShape,
                  textStyle: theme.textTheme.titleSmall,
                ),
                child: content,
              ),
            )
          : PlayerCountdownBar(
              color: Colors.white,
              // Inside the outline, not over it.
              inset: const EdgeInsets.all(_overVideoOutlineWidth),
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
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.6),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Colors.black54),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PixelIcon(
                  volume <= 0 ? PixelGlyph.volumeOff : PixelGlyph.volumeUp,
                  size: 21,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Text(
                  '${volume.round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
