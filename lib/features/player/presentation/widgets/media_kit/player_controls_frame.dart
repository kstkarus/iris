part of '../media_kit_player_viewport_factory.dart';

/// Sits on top of the media_kit controls, in the page and in full screen:
/// offers to skip the opening and to play the next file, shows startup
/// progress in full screen (where the page's overlays are hidden) and
/// reports the full-screen route.
class _PlayerControlsFrame extends StatefulWidget {
  const _PlayerControlsFrame({
    required this.phase,
    required this.finishing,
    required this.completed,
    required this.nextTitle,
    required this.onPlayNext,
    required this.skipSegment,
    required this.onSkip,
    required this.openingLabel,
    required this.bufferingLabel,
    required this.stats,
    required this.onFullscreenRoute,
    required this.onInlineShown,
    required this.child,
  });

  final ValueListenable<PlayerEnginePhase> phase;
  final ValueListenable<bool> finishing;
  final ValueListenable<bool> completed;
  final ValueListenable<String?> nextTitle;
  final VoidCallback onPlayNext;
  final ValueListenable<PlayerSkipSegment?> skipSegment;
  final VoidCallback onSkip;
  final String openingLabel;
  final String bufferingLabel;
  final ValueListenable<PlayerPlaybackStats?> stats;
  final ValueChanged<ModalRoute<Object?>> onFullscreenRoute;
  final VoidCallback onInlineShown;
  final Widget child;

  @override
  State<_PlayerControlsFrame> createState() => _PlayerControlsFrameState();
}

class _PlayerControlsFrameState extends State<_PlayerControlsFrame> {
  final _activity = PlayerPointerActivity();

  @override
  void dispose() {
    _activity.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (isFullscreen(context)) {
      final route = ModalRoute.of(context);
      if (route != null) widget.onFullscreenRoute(route);
    } else {
      widget.onInlineShown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullscreen = isFullscreen(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerHover: (_) => _activity.ping(),
      onPointerDown: (_) => _activity.ping(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          PlayerSkipSegmentOffer(
            segment: widget.skipSegment,
            activity: _activity,
            plate: (label, _) => _PlayerActionPill(
              actionKey: const Key('player_skip_segment_button'),
              label: label,
              onPressed: widget.onSkip,
            ),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: widget.nextTitle,
            builder: (context, title, _) => PlayerNextOffer(
              finishing: widget.finishing,
              completed: widget.completed,
              title: title,
              activity: _activity,
              plate: (label, detail) => _PlayerActionPill(
                actionKey: const Key('player_next_file_prompt'),
                label: label,
                detail: detail,
                onPressed: widget.onPlayNext,
              ),
            ),
          ),
          if (fullscreen)
            // Progress only: the controls (exit full screen, volume) stay
            // usable.
            IgnorePointer(
              child: ValueListenableBuilder<PlayerEnginePhase>(
                valueListenable: widget.phase,
                builder: (context, phase, _) => switch (phase) {
                  PlayerEnginePhase.openingSource => _PlayerStartupOverlay(
                    label: widget.openingLabel,
                    stats: widget.stats,
                  ),
                  PlayerEnginePhase.waitingForFirstFrame =>
                    _PlayerStartupOverlay(
                      label: widget.bufferingLabel,
                      stats: widget.stats,
                    ),
                  PlayerEnginePhase.ready ||
                  PlayerEnginePhase.failed => const SizedBox.shrink(),
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// One action over the video, as in streaming apps; playback never moves
/// on by itself. The label says what it does, so it carries no glyph.
class _PlayerActionPill extends StatelessWidget {
  const _PlayerActionPill({
    required this.actionKey,
    required this.label,
    required this.onPressed,
    this.detail,
  });

  final Key actionKey;
  final String label;
  final String? detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.bottomEnd,
      child: Padding(
        // Clear of the bottom button bar and the seek bar.
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 72),
        child: PlayerCountdownBar(
          color: theme.colorScheme.onPrimary,
          child: FilledButton(
            key: actionKey,
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              // The plate is the whole touch target, so the countdown runs
              // along its visible edge, not below it.
              minimumSize: const Size(64, 48),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: PlayerOfferLabel(
              label: label,
              detail: detail,
              maxWidth: 220,
            ),
          ),
        ),
      ),
    );
  }
}
