import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/presentation/playback/media_kit_player_engine.dart';
import 'package:iris/features/player/presentation/widgets/player_auto_hiding_offer.dart';
import 'package:iris/features/player/presentation/widgets/player_episodes_drawer.dart';
import 'package:iris/features/player/presentation/widgets/player_seek_bar.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/features/player/presentation/widgets/player_wait_indicator.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

/// The player's accent over video: the app's signal, which reads the same
/// on a dark frame in both themes.
Color playerAccentColor(ColorScheme scheme) => scheme.tertiaryFixed;

/// Streaming-app controls drawn over a full-bleed video: the way back and
/// the episodes at the top, play and ±10 s in the middle, the titles and
/// the timeline at the bottom, the episodes in a drawer on the right.
///
/// They hide with the cursor after a few seconds of playback without
/// pointer activity and stay while paused, hovered or with the drawer open.
/// The titles show only while paused, as in streaming apps, and the
/// subtitles move above whatever the controls cover at the bottom.
///
/// Keyboard: Space/K play-pause, ←/→ and J/L ∓10 s, ↑/↓ volume, M mute,
/// F full screen, N next episode, S skip, E episodes, Esc closes the drawer
/// or leaves full screen.
class PlayerImmersiveControls extends StatefulWidget {
  const PlayerImmersiveControls({
    required this.engine,
    required this.chrome,
    required this.video,
    required this.statsPanel,
    this.startupLabel,
    required this.fullscreen,
    required this.onToggleFullscreen,
    required this.onShowTracks,
    required this.onShowSettings,
    this.onSubtitleClearance,
    this.next,
    super.key,
  });

  static const hideAfter = Duration(seconds: 3);
  static const seekStep = Duration(seconds: 10);
  static const volumeStep = 5.0;

  final MediaKitPlayerEngine engine;
  final PlayerChrome chrome;

  /// The video, or the failure in its place.
  final Widget video;

  /// While the stream starts: what it waits for. A spinner takes the play
  /// button's place meanwhile.
  final String? startupLabel;
  final Widget statsPanel;
  final ValueListenable<bool> fullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onShowTracks;
  final VoidCallback onShowSettings;
  final PlayerNextFile? next;

  /// Pixels the visible controls cover at the bottom of a box of the given
  /// size (0 while hidden), so the subtitles can move above them.
  final void Function(double clearance, Size viewSize)? onSubtitleClearance;

  @override
  State<PlayerImmersiveControls> createState() =>
      _PlayerImmersiveControlsState();
}

class _PlayerImmersiveControlsState extends State<PlayerImmersiveControls> {
  final _focusNode = FocusNode(debugLabel: 'player_immersive_controls');
  final _activity = PlayerPointerActivity();

  /// What keeps the controls on screen besides a paused player.
  final _holds = <Object>{};

  Player? _player;
  StreamSubscription<bool>? _playingSubscription;
  bool _playing = false;

  bool _controlsVisible = true;
  bool _episodesOpen = false;
  Timer? _hideTimer;

  /// The bottom controls' parts at their full sizes, so the subtitles move
  /// once per change, not with every frame of the titles' animation.
  double _titleHeight = 0;
  double _barHeight = 0;
  Size _viewSize = Size.zero;

  /// The clearance last decided on, and the one the owner was told.
  double? _targetClearance;
  double? _reportedClearance;
  Size? _reportedViewSize;
  Timer? _lowerSubtitlesTimer;

  double? _volumeHud;
  Timer? _volumeHudTimer;
  double _volumeBeforeMute = 100;

  @override
  void initState() {
    super.initState();
    _attachPlayer();
    _restartHideTimer();
  }

  @override
  void didUpdateWidget(covariant PlayerImmersiveControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    _attachPlayer();
    if (widget.chrome.episodes == null && _episodesOpen) {
      _episodesOpen = false;
    }
  }

  @override
  void dispose() {
    _playingSubscription?.cancel();
    _hideTimer?.cancel();
    _lowerSubtitlesTimer?.cancel();
    _volumeHudTimer?.cancel();
    _activity.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Follows the engine's current player; a new one replaces it when the
  /// decoding preferences change.
  void _attachPlayer() {
    final engine = widget.engine;
    final player = engine.hasPlayer ? engine.player : null;
    if (identical(player, _player)) return;
    _playingSubscription?.cancel();
    _player = player;
    _playing = player?.state.playing ?? false;
    _playingSubscription = player?.stream.playing.listen(_onPlaying);
  }

  void _onPlaying(bool playing) {
    if (!mounted || playing == _playing) return;
    setState(() {
      _playing = playing;
      if (!playing) _controlsVisible = true;
    });
    if (playing) _restartHideTimer();
  }

  /// The bottom controls' height once the titles finish showing or hiding.
  double get _bottomHeight =>
      _barHeight + _BottomSection.bottomPadding + (_playing ? 0 : _titleHeight);

  /// Tells the owner how much of the bottom the controls cover. The
  /// subtitles rise at once, before the titles grow under them, and come
  /// down only after the titles have collapsed.
  void _reportSubtitleClearance() {
    final report = widget.onSubtitleClearance;
    if (report == null) return;
    // A little air between the subtitles and the controls.
    final clearance = _controlsVisible && _barHeight > 0
        ? _bottomHeight + 12
        : 0.0;
    final viewSize = _viewSize;
    if (clearance == _targetClearance && viewSize == _reportedViewSize) return;
    _targetClearance = clearance;
    _lowerSubtitlesTimer?.cancel();

    void send() {
      if (!mounted) return;
      _reportedClearance = clearance;
      _reportedViewSize = viewSize;
      report(clearance, viewSize);
    }

    final reported = _reportedClearance;
    if (reported != null &&
        clearance < reported &&
        viewSize == _reportedViewSize) {
      _lowerSubtitlesTimer = Timer(_BottomSection.titleAnimation, send);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => send());
    }
  }

  void _onTitleHeight(double height) {
    if (mounted && height != _titleHeight) {
      setState(() => _titleHeight = height);
    }
  }

  void _onBarHeight(double height) {
    if (mounted && height != _barHeight) setState(() => _barHeight = height);
  }

  void _showControls() {
    _activity.ping();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _restartHideTimer();
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(PlayerImmersiveControls.hideAfter, _hideIfIdle);
  }

  void _hideIfIdle() {
    if (!mounted || !_playing || _episodesOpen || _holds.isNotEmpty) return;
    setState(() => _controlsVisible = false);
  }

  void _setHold(Object reason, bool held) {
    if (held) {
      _holds.add(reason);
      return;
    }
    if (_holds.remove(reason)) _restartHideTimer();
  }

  void _togglePlay() {
    _focusNode.requestFocus();
    final player = _player;
    if (player == null) return;
    unawaited(player.playOrPause());
  }

  void _seekBy(Duration delta) {
    final player = _player;
    if (player == null) return;
    final duration = player.state.duration;
    var target = player.state.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    unawaited(widget.engine.seek(target));
    _showControls();
  }

  void _seekTo(Duration position) {
    unawaited(widget.engine.seek(position));
  }

  void _setVolume(double volume, {bool showHud = true}) {
    final player = _player;
    if (player == null) return;
    final clamped = volume.clamp(0.0, 100.0);
    unawaited(player.setVolume(clamped));
    if (!showHud) return;
    _volumeHudTimer?.cancel();
    setState(() => _volumeHud = clamped);
    _volumeHudTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _volumeHud = null);
    });
  }

  void _changeVolume(double delta) {
    final player = _player;
    if (player == null) return;
    _setVolume(player.state.volume + delta);
  }

  void _toggleMute() {
    final player = _player;
    if (player == null) return;
    final volume = player.state.volume;
    if (volume > 0) {
      _volumeBeforeMute = volume;
      _setVolume(0);
    } else {
      _setVolume(_volumeBeforeMute > 0 ? _volumeBeforeMute : 100);
    }
  }

  void _skip() {
    if (widget.engine.skipSegment.value != null) {
      unawaited(widget.engine.skipCurrentSegment());
    } else if (widget.engine.skipForwardOffered.value) {
      unawaited(widget.engine.skipForward());
    }
  }

  void _openEpisodes() {
    if (widget.chrome.episodes == null) return;
    setState(() {
      _episodesOpen = true;
      _controlsVisible = true;
    });
  }

  void _closeEpisodes() {
    if (!_episodesOpen) return;
    setState(() => _episodesOpen = false);
    _focusNode.requestFocus();
    _restartHideTimer();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (_episodesOpen || event is! PointerScrollEvent) return;
    final dy = event.scrollDelta.dy;
    if (dy == 0) return;
    const step = PlayerImmersiveControls.volumeStep;
    _changeVolume(dy < 0 ? step : -step);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    const step = PlayerImmersiveControls.seekStep;
    const volumeStep = PlayerImmersiveControls.volumeStep;

    // Held keys repeat only for seeking and volume.
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) {
      _seekBy(-step);
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyL) {
      _seekBy(step);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _changeVolume(volumeStep);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _changeVolume(-volumeStep);
    } else if (event is KeyRepeatEvent) {
      return KeyEventResult.ignored;
    } else if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.keyK) {
      _togglePlay();
      _showControls();
    } else if (key == LogicalKeyboardKey.keyF) {
      widget.onToggleFullscreen();
    } else if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
    } else if (key == LogicalKeyboardKey.keyN && widget.next != null) {
      widget.next!.play();
    } else if (key == LogicalKeyboardKey.keyS) {
      _skip();
    } else if (key == LogicalKeyboardKey.keyE) {
      _episodesOpen ? _closeEpisodes() : _openEpisodes();
    } else if (key == LogicalKeyboardKey.escape) {
      if (_episodesOpen) {
        _closeEpisodes();
      } else if (widget.fullscreen.value) {
        widget.onToggleFullscreen();
      } else {
        return KeyEventResult.ignored;
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final accent = playerAccentColor(Theme.of(context).colorScheme);
    final player = _player;
    final visible = _controlsVisible;
    _reportSubtitleClearance();

    final controls = Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: visible ? MouseCursor.defer : SystemMouseCursors.none,
        onHover: (_) => _showControls(),
        child: Listener(
          onPointerDown: (_) => _showControls(),
          onPointerSignal: _onPointerSignal,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Colors.black, child: widget.video),
              // A paused frame steps back behind the titles and controls.
              IgnorePointer(
                child: AnimatedOpacity(
                  key: const Key('player_pause_dim'),
                  opacity: !_playing && widget.startupLabel == null ? 1 : 0,
                  duration: _BottomSection.titleAnimation,
                  child: const ColoredBox(color: Color(0x59000000)),
                ),
              ),
              GestureDetector(
                key: const Key('player_immersive_tap_layer'),
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlay,
                onDoubleTap: widget.onToggleFullscreen,
              ),
              _BufferingSpinner(
                engine: widget.engine,
                color: accent,
                startupLabel: widget.startupLabel,
              ),
              IgnorePointer(
                ignoring: !visible,
                child: AnimatedOpacity(
                  key: const Key('player_immersive_controls'),
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: player == null
                      ? const SizedBox.shrink()
                      : _buildControls(context, player, accent),
                ),
              ),
              _buildOffers(context),
              if (widget.chrome.notice case final notice?)
                Positioned(
                  left: 48,
                  bottom: _barHeight > 0
                      ? _bottomHeight + 12
                      : _BottomSection.offerClearance,
                  child: _NoticeCard(notice: notice, accent: accent),
                ),
              if (_volumeHud case final volume?)
                _VolumeHud(key: const Key('player_volume_hud'), volume: volume),
              if (_episodesOpen && widget.chrome.episodes != null)
                PlayerEpisodesDrawer(
                  onClose: _closeEpisodes,
                  builder: widget.chrome.episodes!,
                  caption: widget.chrome.episodesCaption,
                ),
            ],
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewSize = constraints.biggest;
        // Hover tooltips get in the way over video (the stats chips have
        // some); the controls label themselves for screen readers instead.
        return TooltipVisibility(visible: false, child: controls);
      },
    );
  }

  Widget _buildControls(BuildContext context, Player player, Color accent) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _Scrims(),
        Align(
          alignment: Alignment.topCenter,
          child: MouseRegion(
            onEnter: (_) => _setHold(#top, true),
            onExit: (_) => _setHold(#top, false),
            child: _TopBar(
              chrome: widget.chrome,
              statsPanel: widget.statsPanel,
            ),
          ),
        ),
        Center(
          child: _CenterButtons(
            player: player,
            engine: widget.engine,
            starting: widget.startupLabel != null,
            onPlayPause: _togglePlay,
            onBackward: () => _seekBy(-PlayerImmersiveControls.seekStep),
            onForward: () => _seekBy(PlayerImmersiveControls.seekStep),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: MouseRegion(
            onEnter: (_) => _setHold(#bottom, true),
            onExit: (_) => _setHold(#bottom, false),
            child: _BottomSection(
              chrome: widget.chrome,
              showTitle: !_playing,
              onTitleHeight: _onTitleHeight,
              onBarHeight: _onBarHeight,
              player: player,
              accent: accent,
              next: widget.next,
              fullscreen: widget.fullscreen,
              onSeek: _seekTo,
              onSeekActive: (active) => _setHold(#seek, active),
              onToggleMute: _toggleMute,
              onVolume: (volume) => _setVolume(volume, showHud: false),
              onShowTracks: widget.onShowTracks,
              onShowSettings: widget.onShowSettings,
              onToggleFullscreen: widget.onToggleFullscreen,
              onEpisodes: widget.chrome.episodes == null ? null : _openEpisodes,
            ),
          ),
        ),
      ],
    );
  }

  /// Skip and next-episode offers sit above the timeline on the right.
  Widget _buildOffers(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = widget.engine;
    final next = widget.next;

    return Positioned(
      right: 48,
      bottom: _BottomSection.offerClearance,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ValueListenableBuilder<PlayerSkipSegment?>(
            valueListenable: engine.skipSegment,
            builder: (context, segment, _) {
              if (segment == null) {
                return _SkipForwardOffer(
                  engine: engine,
                  visible: _controlsVisible,
                );
              }
              return PlayerAutoHidingOffer(
                key: ValueKey(segment),
                activity: _activity,
                child: _OfferButton.outlined(
                  key: const Key('player_skip_segment_button'),
                  label: segment.kind == PlayerSkipKind.recap
                      ? l10n.playerSkipRecap
                      : l10n.playerSkipOpening,
                  onPressed: () => unawaited(engine.skipCurrentSegment()),
                ),
              );
            },
          ),
          if (next != null)
            ListenableBuilder(
              listenable: Listenable.merge([
                engine.finishing,
                engine.completed,
              ]),
              builder: (context, _) {
                final completed = engine.completed.value;
                if (!(engine.finishing.value || completed)) {
                  return const SizedBox.shrink();
                }
                return PlayerAutoHidingOffer(
                  activity: _activity,
                  // Once the file has ended there is nothing left to cover.
                  pinned: completed,
                  child: _OfferButton.filled(
                    key: const Key('player_next_file_prompt'),
                    label: l10n.playerPlayNext,
                    detail: next.title,
                    onPressed: next.play,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Scrims extends StatelessWidget {
  const _Scrims();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Column(
        children: [
          SizedBox(
            height: 160,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB3000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
          Spacer(),
          SizedBox(
            height: 320,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x99000000),
                    Color(0xE6000000),
                  ],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.chrome, required this.statsPanel});

  final PlayerChrome chrome;
  final Widget statsPanel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      // The arrow's glyph starts in line with the titles and the timeline.
      padding: const EdgeInsets.fromLTRB(36, 20, 48, 20),
      child: Row(
        // A first row of details sits on the arrow's axis; more rows of
        // them grow downwards.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GlyphButton(
            key: const Key('player_back_button'),
            glyph: const PixelIcon(PixelGlyph.arrowLeft),
            iconSize: 28,
            size: const Size.square(44),
            label: l10n.playerBack,
            onPressed: chrome.onBack,
          ),
          const SizedBox(width: 12),
          statsPanel,
        ],
      ),
    );
  }
}

/// A state glyph (play/pause, mute, full screen) cross-fades this fast, or
/// swaps at once when the system asks for less motion.
Duration _glyphSwapDuration(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 150);

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
    required this.player,
    required this.engine,
    required this.starting,
    required this.onPlayPause,
    required this.onBackward,
    required this.onForward,
  });

  final Player player;
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
            return StreamBuilder<bool>(
              stream: player.stream.playing,
              initialData: player.state.playing,
              builder: (context, snapshot) {
                final playing = snapshot.data ?? false;
                return _PlayPauseButton(
                  playing: playing,
                  label: playing
                      ? l10n.playerPauseButton
                      : l10n.playerPlayButton,
                  onPressed: onPlayPause,
                );
              },
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
                child: AnimatedSwitcher(
                  duration: _glyphSwapDuration(context),
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
    required this.onShowTracks,
    required this.onShowSettings,
    required this.onToggleFullscreen,
    required this.onEpisodes,
  });

  static const _leftPadding = 48.0;

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
  final VoidCallback onShowTracks;
  final VoidCallback onShowSettings;
  final VoidCallback onToggleFullscreen;
  final VoidCallback? onEpisodes;

  @override
  Widget build(BuildContext context) {
    final section = Padding(
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
    return section;
  }
}

/// Reports its child's height after each layout that changes it.
class _HeightReporter extends SingleChildRenderObjectWidget {
  const _HeightReporter({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeightReporter(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeightReporter renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderHeightReporter extends RenderProxyBox {
  _RenderHeightReporter(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    // Layout must not rebuild widgets; report once it is done.
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
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
  final VoidCallback onShowTracks;
  final VoidCallback onShowSettings;
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
      _BarButton(
        key: const Key('player_tracks_button'),
        glyph: const PixelIcon(PixelGlyph.subtitles),
        label: l10n.playerAudioAndSubtitles,
        onPressed: onShowTracks,
      ),
      _BarButton(
        key: const Key('player_settings_button'),
        glyph: const PixelIcon(PixelGlyph.settings),
        label: l10n.playerSettingsTitle,
        onPressed: onShowSettings,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, group) in groups.indexed) ...[
          if (index > 0) const SizedBox(width: _barGroupGap),
          ...group,
        ],
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
    super.key,
  });

  static const glyphSize = 24.0;

  final Widget glyph;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _GlyphButton(
      glyph: glyph,
      iconSize: glyphSize,
      size: const Size(_barButtonSize + 4, _barButtonSize),
      label: label,
      onPressed: onPressed,
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
    super.key,
  });

  static const restOpacity = 0.85;

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
    final active = _hovered || _focused;
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
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: _animation,
              width: widget.size.width,
              height: widget.size.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: _focused ? Colors.white70 : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: AnimatedScale(
                  scale: _hovered ? 1.12 : 1,
                  duration: _animation,
                  child: AnimatedOpacity(
                    opacity: active ? 1 : _GlyphButton.restOpacity,
                    duration: _animation,
                    child: IconTheme.merge(
                      data: IconThemeData(
                        size: widget.iconSize,
                        color: Colors.white,
                      ),
                      // The button's label speaks for it; a figure such
                      // as "+10" must not be read out on top of it.
                      child: ExcludeSemantics(
                        child: AnimatedSwitcher(
                          duration: _glyphSwapDuration(context),
                          child: _ShadowedGlyph(
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

/// Secondary buttons over the video: a dark glass with a light outline.
ButtonStyle _overVideoButtonStyle(ThemeData theme) {
  return OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    shape: const RoundedRectangleBorder(),
    foregroundColor: Colors.white,
    backgroundColor: Colors.black54,
    side: const BorderSide(color: Colors.white70, width: 1.5),
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
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
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
            duration: const Duration(milliseconds: 250),
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
    final detail = this.detail;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          if (detail != null)
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: theme.textTheme.labelSmall?.fontSize,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
    );
    const padding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    const shape = RoundedRectangleBorder();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding: padding,
                shape: shape,
                textStyle: theme.textTheme.titleSmall,
              ),
              child: content,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: _overVideoButtonStyle(theme),
              child: content,
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
