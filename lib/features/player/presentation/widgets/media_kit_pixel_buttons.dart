import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/features/player/presentation/widgets/player_glyph_switcher.dart';

/// Play/pause for media_kit's phone controls, drawn with the app's pixel
/// glyphs in place of the package's Material icon.
class PixelPlayOrPauseButton extends StatelessWidget {
  const PixelPlayOrPauseButton({super.key});

  static const _size = 44.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final player = _player(context);
    return StreamBuilder<bool>(
      // A new player starts over from its own state.
      key: ObjectKey(player),
      stream: player.stream.playing,
      initialData: player.state.playing,
      builder: (context, snapshot) {
        final playing = snapshot.requireData;
        return IconButton(
          tooltip: playing ? l10n.playerPauseButton : l10n.playerPlayButton,
          iconSize: _size,
          onPressed: player.playOrPause,
          icon: PlayerGlyphSwitcher(
            child: _glyph(playing ? PixelGlyph.pause : PixelGlyph.play, _size),
          ),
        );
      },
    );
  }
}

Player _player(BuildContext context) =>
    VideoStateInheritedWidget.of(context).state.widget.controller.player;

/// Full screen on/off for media_kit's phone controls, in pixel glyphs.
class PixelFullscreenButton extends StatelessWidget {
  const PixelFullscreenButton({super.key});

  static const _size = 24.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fullscreen = isFullscreen(context);
    return IconButton(
      tooltip: fullscreen
          ? l10n.playerExitFullscreen
          : l10n.playerEnterFullscreen,
      iconSize: _size,
      onPressed: () => toggleFullscreen(context),
      icon: PlayerGlyphSwitcher(
        child: _glyph(
          fullscreen ? PixelGlyph.fullscreenExit : PixelGlyph.fullscreen,
          _size,
        ),
      ),
    );
  }
}

PixelIcon _glyph(PixelGlyph glyph, double size) =>
    PixelIcon(glyph, key: ValueKey(glyph), size: size);
