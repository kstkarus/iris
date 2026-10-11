part of '../player_immersive_controls.dart';

class _BottomSection extends StatelessWidget {
  const _BottomSection({
    required this.chrome,
    required this.showTitle,
    required this.onTitleHeight,
    required this.onBarHeight,
    required this.player,
    required this.accent,
    required this.next,
    required this.fullscreen,
    required this.onSeek,
    required this.onSeekActive,
    required this.onToggleMute,
    required this.onVolume,
    required this.openPanel,
    required this.onShowTracks,
    required this.onShowSettings,
    required this.onToggleFullscreen,
    required this.onEpisodes,
  });

  static const _leftPadding = _sideInset;

  /// Less than on the left: the last button's glyph, not its hit area,
  /// ends in line with the offers above.
  static const _rightPadding = 34.0;
  static const _buttonInset = _leftPadding - _rightPadding;
  static const bottomPadding = 24.0;
  static const titleAnimation = Duration(milliseconds: 200);
  static const _barHeight = PlayerSeekBar.height;

  /// Where offers over the video stop, clear of the timeline.
  static const offerClearance = bottomPadding + _barHeight + 24;

  /// Narrower windows put the buttons on their own row.
  static const _singleRowMinWidth = 720.0;

  final PlayerChrome chrome;

  /// The titles take room only while paused.
  final bool showTitle;

  /// The titles' full height, also while they animate in.
  final ValueChanged<double> onTitleHeight;

  /// The timeline and buttons' height.
  final ValueChanged<double> onBarHeight;
  final Player player;
  final Color accent;
  final PlayerNextFile? next;
  final ValueListenable<bool> fullscreen;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<bool> onSeekActive;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolume;
  final Object? openPanel;
  final ValueChanged<BuildContext> onShowTracks;
  final ValueChanged<BuildContext> onShowSettings;
  final VoidCallback onToggleFullscreen;
  final VoidCallback? onEpisodes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _leftPadding,
        0,
        _rightPadding,
        bottomPadding,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final singleRow = constraints.maxWidth >= _singleRowMinWidth;
          final timeline = _Timeline(
            player: player,
            accent: accent,
            onSeek: onSeek,
            onSeekActive: onSeekActive,
          );
          final buttons = _BarButtons(
            player: player,
            next: next,
            fullscreen: fullscreen,
            onToggleMute: onToggleMute,
            onVolume: onVolume,
            openPanel: openPanel,
            onShowTracks: onShowTracks,
            onShowSettings: onShowSettings,
            onToggleFullscreen: onToggleFullscreen,
            onEpisodes: onEpisodes,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSize(
                duration: titleAnimation,
                alignment: Alignment.bottomLeft,
                child: showTitle
                    ? _HeightReporter(
                        onHeight: onTitleHeight,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  constraints.maxWidth * (singleRow ? 0.55 : 1),
                            ),
                            child: _TitleBlock(chrome: chrome),
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              _HeightReporter(
                onHeight: onBarHeight,
                child: singleRow
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: timeline),
                          const SizedBox(width: 12),
                          buttons,
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: _buttonInset),
                            child: timeline,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: buttons,
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.chrome});

  final PlayerChrome chrome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overline = chrome.overline;
    final details = chrome.details;
    final title = chrome.title;
    final titleDetail = chrome.titleDetail;
    // File names can be long; episode labels get the full display size.
    final titleStyle = title.length > 32
        ? theme.textTheme.headlineSmall
        : theme.textTheme.displaySmall;

    return Column(
      key: const Key('player_title_block'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (overline != null && overline.isNotEmpty) ...[
          Text(
            overline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text.rich(
          TextSpan(
            text: title,
            children: [
              if (titleDetail != null && titleDetail.isNotEmpty)
                TextSpan(
                  text: ' $titleDetail',
                  style: TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.w400,
                    fontSize: theme.textTheme.headlineSmall?.fontSize,
                  ),
                ),
            ],
          ),
          key: const Key('player_title'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            height: 1.1,
          ),
        ),
        if (details != null && details.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            details,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
          ),
        ],
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.player,
    required this.accent,
    required this.onSeek,
    required this.onSeekActive,
  });

  final Player player;
  final Color accent;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<bool> onSeekActive;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.duration,
      initialData: player.state.duration,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.stream.buffer,
          initialData: player.state.buffer,
          builder: (context, bufferSnapshot) {
            return StreamBuilder<Duration>(
              stream: player.stream.position,
              initialData: player.state.position,
              builder: (context, positionSnapshot) {
                final position = positionSnapshot.data ?? Duration.zero;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: PlayerSeekBar(
                        position: position,
                        duration: duration,
                        buffered: bufferSnapshot.data ?? Duration.zero,
                        color: accent,
                        onSeek: onSeek,
                        onActiveChanged: onSeekActive,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _TimeReadout(position: position, duration: duration),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Time left as `−17:34`; a click switches to where playback is and the
/// file's length, `5:23 / 23:00`, and back.
class _TimeReadout extends StatefulWidget {
  const _TimeReadout({required this.position, required this.duration});

  final Duration position;
  final Duration duration;

  @override
  State<_TimeReadout> createState() => _TimeReadoutState();
}

class _TimeReadoutState extends State<_TimeReadout> {
  bool _elapsed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final duration = widget.duration;
    final known = duration > Duration.zero;
    var left = known ? duration - widget.position : Duration.zero;
    if (left < Duration.zero) left = Duration.zero;
    final String text;
    final String label;
    if (_elapsed) {
      final position = formatPlaybackPosition(widget.position);
      final length = formatPlaybackPosition(duration);
      text = known ? '$position / $length' : position;
      label = l10n.playerTimePosition(position, length);
    } else {
      final time = formatPlaybackPosition(left);
      // A real minus sign, as wide as the digits.
      text = known ? '\u2212$time' : time;
      label = l10n.playerTimeLeft(time);
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: const Key('player_time_toggle'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _elapsed = !_elapsed),
        child: SizedBox(
          height: _barButtonSize,
          child: Center(
            child: Text(
              text,
              key: const Key('player_time_left'),
              semanticsLabel: label,
              style: playerTimeStyle,
            ),
          ),
        ),
      ),
    );
  }
}

const _barButtonSize = 40.0;

class _BarButtons extends StatelessWidget {
  const _BarButtons({
    required this.player,
    required this.next,
    required this.fullscreen,
    required this.onToggleMute,
    required this.onVolume,
    required this.openPanel,
    required this.onShowTracks,
    required this.onShowSettings,
    required this.onToggleFullscreen,
    required this.onEpisodes,
  });

  final Player player;
  final PlayerNextFile? next;
  final ValueListenable<bool> fullscreen;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolume;
  final Object? openPanel;
  final ValueChanged<BuildContext> onShowTracks;
  final ValueChanged<BuildContext> onShowSettings;
  final VoidCallback onToggleFullscreen;
  final VoidCallback? onEpisodes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final next = this.next;
    final onEpisodes = this.onEpisodes;
    final playback = [
      if (next != null)
        _BarButton(
          key: const Key('player_next_file_button'),
          glyph: const PixelIcon(PixelGlyph.skipNext),
          label: '${l10n.playerPlayNext}: ${next.title}',
          onPressed: next.play,
        ),
      if (onEpisodes != null)
        _BarButton(
          key: const Key('player_episodes_button'),
          glyph: const PixelIcon(PixelGlyph.episodes),
          label: l10n.playerEpisodesTitle,
          onPressed: onEpisodes,
        ),
    ];
    final view = [
      // The panels open from their buttons, which stay lit meanwhile.
      Builder(
        builder: (anchor) => _BarButton(
          key: const Key('player_tracks_button'),
          glyph: const PixelIcon(PixelGlyph.subtitles),
          label: l10n.playerAudioAndSubtitles,
          selected: openPanel == #tracks,
          onPressed: () => onShowTracks(anchor),
        ),
      ),
      Builder(
        builder: (anchor) => _BarButton(
          key: const Key('player_settings_button'),
          glyph: const PixelIcon(PixelGlyph.settings),
          label: l10n.playerSettingsTitle,
          selected: openPanel == #settings,
          onPressed: () => onShowSettings(anchor),
        ),
      ),
      ValueListenableBuilder<bool>(
        valueListenable: fullscreen,
        builder: (context, isFullscreen, _) => _BarButton(
          key: const Key('player_fullscreen_button'),
          glyph: PixelIcon(
            isFullscreen ? PixelGlyph.fullscreenExit : PixelGlyph.fullscreen,
            key: ValueKey(isFullscreen),
          ),
          label: isFullscreen
              ? l10n.playerExitFullscreen
              : l10n.playerEnterFullscreen,
          onPressed: onToggleFullscreen,
        ),
      ),
    ];
    // Volume, then what to watch, then how to watch it.
    final groups = [
      [
        _VolumeControl(
          player: player,
          onToggleMute: onToggleMute,
          onVolume: onVolume,
        ),
      ],
      playback,
      view,
    ].where((group) => group.isNotEmpty);
    // A group stays whole; a window too narrow for all of them moves the
    // last ones to a second line, still ending at the right edge.
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: _barGroupGap,
      children: [
        for (final group in groups)
          Row(mainAxisSize: MainAxisSize.min, children: group),
      ],
    );
  }
}

const _barGroupGap = 20.0;

/// A button of the bottom bar. Pixel glyphs all fill their 7×7 grid, so
/// one size fits every button.
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.glyph,
    required this.label,
    required this.onPressed,
    this.selected = false,
    super.key,
  });

  static const glyphSize = 24.0;

  final Widget glyph;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _GlyphButton(
      glyph: glyph,
      iconSize: glyphSize,
      size: const Size(_barButtonSize + 4, _barButtonSize),
      label: label,
      selected: selected,
      onPressed: onPressed,
    );
  }
}

/// Mute button; hovering reveals a volume slider beside it.
class _VolumeControl extends StatefulWidget {
  const _VolumeControl({
    required this.player,
    required this.onToggleMute,
    required this.onVolume,
  });

  final Player player;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolume;

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = playerAccentColor(Theme.of(context).colorScheme);
    return MouseRegion(
      onEnter: (_) => setState(() => _expanded = true),
      onExit: (_) => setState(() => _expanded = false),
      child: StreamBuilder<double>(
        stream: widget.player.stream.volume,
        initialData: widget.player.state.volume,
        builder: (context, snapshot) {
          final volume = snapshot.data ?? 100;
          final muted = volume <= 0;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 150),
                child: _expanded
                    ? SizedBox(
                        width: 104,
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            activeTrackColor: accent,
                            inactiveTrackColor: Colors.white30,
                            thumbColor: accent,
                            overlayShape: SliderComponentShape.noOverlay,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                          ),
                          child: Slider(
                            key: const Key('player_volume_slider'),
                            value: volume.clamp(0.0, 100.0),
                            max: 100,
                            onChanged: widget.onVolume,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              _BarButton(
                key: const Key('player_mute_button'),
                glyph: () {
                  final glyph = muted
                      ? PixelGlyph.volumeOff
                      : volume < 50
                      ? PixelGlyph.volumeDown
                      : PixelGlyph.volumeUp;
                  return PixelIcon(glyph, key: ValueKey(glyph));
                }(),
                label: muted ? l10n.playerUnmute : l10n.playerMute,
                onPressed: widget.onToggleMute,
              ),
            ],
          );
        },
      ),
    );
  }
}
