import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

/// Play/pause for media_kit's phone controls, drawn with the app's pixel
/// glyphs in place of the package's Material icon.
class PixelPlayOrPauseButton extends StatefulWidget {
  const PixelPlayOrPauseButton({this.size = 44, super.key});

  final double size;

  @override
  State<PixelPlayOrPauseButton> createState() => _PixelPlayOrPauseButtonState();
}

class _PixelPlayOrPauseButtonState extends State<PixelPlayOrPauseButton> {
  StreamSubscription<bool>? _subscription;
  bool _playing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final player = _player(context);
    _playing = player.state.playing;
    _subscription?.cancel();
    _subscription = player.stream.playing.listen((playing) {
      if (mounted) setState(() => _playing = playing);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: _playing ? l10n.playerPauseButton : l10n.playerPlayButton,
      iconSize: widget.size,
      onPressed: _player(context).playOrPause,
      icon: _GlyphSwitcher(
        glyph: _playing ? PixelGlyph.pause : PixelGlyph.play,
        size: widget.size,
      ),
    );
  }
}

Player _player(BuildContext context) =>
    VideoStateInheritedWidget.of(context).state.widget.controller.player;

/// Full screen on/off for media_kit's phone controls, in pixel glyphs.
class PixelFullscreenButton extends StatelessWidget {
  const PixelFullscreenButton({this.size = 24, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fullscreen = isFullscreen(context);
    return IconButton(
      tooltip: fullscreen
          ? l10n.playerExitFullscreen
          : l10n.playerEnterFullscreen,
      iconSize: size,
      onPressed: () => toggleFullscreen(context),
      icon: _GlyphSwitcher(
        glyph: fullscreen ? PixelGlyph.fullscreenExit : PixelGlyph.fullscreen,
        size: size,
      ),
    );
  }
}

/// Cross-fades a glyph when the state it shows changes; at once when
/// animations are off.
class _GlyphSwitcher extends StatelessWidget {
  const _GlyphSwitcher({required this.glyph, required this.size});

  final PixelGlyph glyph;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 150),
      child: PixelIcon(glyph, key: ValueKey(glyph), size: size),
    );
  }
}
