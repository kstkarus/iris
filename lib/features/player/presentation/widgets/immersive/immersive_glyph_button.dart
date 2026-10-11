part of '../player_immersive_controls.dart';

/// [glyph] over a soft dark copy of itself, so a white glyph stays
/// readable over a bright frame.
class _ShadowedGlyph extends StatelessWidget {
  const _ShadowedGlyph({required this.glyph, super.key});

  final Widget glyph;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: IconTheme.merge(
            data: const IconThemeData(color: Colors.black54),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.black54),
              child: glyph,
            ),
          ),
        ),
        glyph,
      ],
    );
  }
}

/// "−10" / "+10": the seek step as a figure, which says more than any
/// arrow could.
class _SeekFigure extends StatelessWidget {
  const _SeekFigure(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _CenterButtons extends StatelessWidget {
  const _CenterButtons({
    required this.playing,
    required this.engine,
    required this.starting,
    required this.onPlayPause,
    required this.onBackward,
    required this.onForward,
  });

  final bool playing;
  final MediaKitPlayerEngine engine;
  final bool starting;
  final VoidCallback onPlayPause;
  final VoidCallback onBackward;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seconds = PlayerImmersiveControls.seekStep.inSeconds;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GlyphButton(
          key: const Key('player_seek_backward_button'),
          glyph: _SeekFigure('\u2212$seconds'),
          iconSize: 44,
          size: const Size.square(60),
          label: l10n.playerSeekBackward(seconds),
          onPressed: onBackward,
        ),
        const SizedBox(width: 48),
        ListenableBuilder(
          listenable: Listenable.merge([engine.buffering, engine.phase]),
          builder: (context, _) {
            final waiting =
                starting ||
                engine.buffering.value ||
                engine.phase.value != PlayerEnginePhase.ready;
            // The spinner takes the button's place while the stream waits.
            if (waiting) return const SizedBox.square(dimension: 96);
            return _PlayPauseButton(
              playing: playing,
              label: playing ? l10n.playerPauseButton : l10n.playerPlayButton,
              onPressed: onPlayPause,
            );
          },
        ),
        const SizedBox(width: 48),
        _GlyphButton(
          key: const Key('player_seek_forward_button'),
          glyph: _SeekFigure('+$seconds'),
          iconSize: 44,
          size: const Size.square(60),
          label: l10n.playerSeekForward(seconds),
          onPressed: onForward,
        ),
      ],
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  const _PlayPauseButton({
    required this.playing,
    required this.label,
    required this.onPressed,
  });

  final bool playing;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          key: const Key('player_play_pause_button'),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _hovered ? 1.08 : 1,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: _hovered ? Colors.white12 : Colors.black38,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Center(
                child: PlayerGlyphSwitcher(
                  child: PixelIcon(
                    widget.playing ? PixelGlyph.pause : PixelGlyph.play,
                    key: ValueKey(widget.playing),
                    size: 42,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bare glyph over the video: slightly dimmed at rest, full white and a
/// little larger under the pointer, no Material circle behind it. Clicks
/// leave the focus with the player, so a ring shows only when the keyboard
/// moved it here.
class _GlyphButton extends StatefulWidget {
  const _GlyphButton({
    required this.glyph,
    required this.iconSize,
    required this.size,
    required this.label,
    required this.onPressed,
    this.selected = false,
    super.key,
  });

  static const restOpacity = 0.85;

  /// Its panel is open: an inverse square, as the chosen cell of a
  /// segmented choice.
  final bool selected;

  /// A [PixelIcon] or a short figure; give it a key that changes with the
  /// state it shows, and it cross-fades when the state flips.
  final Widget glyph;
  final double iconSize;
  final Size size;

  /// For screen readers; hover tooltips get in the way over video.
  final String label;
  final VoidCallback onPressed;

  @override
  State<_GlyphButton> createState() => _GlyphButtonState();
}

class _GlyphButtonState extends State<_GlyphButton> {
  static const _animation = Duration(milliseconds: 120);

  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final active = _hovered || _focused || selected;
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onFocusChange: (focused) => setState(() => _focused = focused),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Semantics(
          button: true,
          label: widget.label,
          // The open panel's button reads as selected, as it looks.
          selected: selected ? true : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: _animation,
              width: widget.size.width,
              height: widget.size.height,
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                border: Border.all(
                  color: _focused ? Colors.white70 : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: AnimatedScale(
                  scale: _hovered && !selected ? 1.12 : 1,
                  duration: _animation,
                  child: AnimatedOpacity(
                    opacity: active ? 1 : _GlyphButton.restOpacity,
                    duration: _animation,
                    child: IconTheme.merge(
                      data: IconThemeData(
                        size: widget.iconSize,
                        color: selected ? Colors.black : Colors.white,
                      ),
                      // The button's label speaks for it; a figure such
                      // as "+10" must not be read out on top of it.
                      child: ExcludeSemantics(
                        child: PlayerGlyphSwitcher(
                          // On the light square the glyph needs no shadow.
                          child: selected
                              ? widget.glyph
                              : _ShadowedGlyph(
                                  key: widget.glyph.key,
                                  glyph: widget.glyph,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
