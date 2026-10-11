import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'package:iris/features/player/presentation/playback/media_kit_player_engine.dart';
import 'package:iris/features/player/presentation/widgets/player_auto_hiding_offer.dart';
import 'package:iris/features/player/presentation/widgets/player_countdown.dart';
import 'package:iris/features/player/presentation/widgets/player_episodes_drawer.dart';
import 'package:iris/features/player/presentation/widgets/player_seek_bar.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/features/player/presentation/widgets/player_wait_indicator.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/features/player/presentation/widgets/player_glyph_switcher.dart';
import 'package:iris/features/player/presentation/widgets/player_offers.dart';
import 'package:iris/features/player/presentation/widgets/player_colors.dart';

part 'immersive/immersive_glyph_button.dart';
part 'immersive/immersive_bottom_bar.dart';
part 'immersive/immersive_plates.dart';
part 'immersive/height_reporter.dart';
part 'immersive/controls_metrics.dart';

/// How fast the controls, and what hides with them, fade.
const _controlsFade = Duration(milliseconds: 250);

/// Opens a panel as a popover of [anchor], its button; completes when the
/// panel closes.
typedef PlayerPanelOpener = Future<void> Function(BuildContext anchor);

/// Streaming-app controls drawn over a full-bleed video: the way back and
/// the episodes at the top, play and ±10 s in the middle, the titles and
/// the timeline at the bottom, the episodes in a drawer on the right.
///
/// With a pointer they hide with the cursor after a few seconds of
/// playback without pointer activity and stay while paused, hovered or
/// with the drawer open; a click on the video plays or pauses. By touch a
/// tap on the video shows or hides them, a touch on them keeps them a
/// while longer, and the buttons are finger-sized; the volume and full
/// screen are the phone's own. The titles show only while paused, as in
/// streaming apps, and the subtitles move above whatever the controls
/// cover at the bottom. Back closes the open drawer first.
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
    this.failure,
    required this.fullscreen,
    required this.onToggleFullscreen,
    required this.onShowTracks,
    required this.onShowSettings,
    this.input = PlayerInputMode.pointer,
    this.onSubtitleClearance,
    this.next,
    super.key,
  });

  static const hideAfter = Duration(seconds: 3);
  static const seekStep = Duration(seconds: 10);
  static const volumeStep = 5.0;

  final MediaKitPlayerEngine engine;
  final PlayerChrome chrome;
  final PlayerInputMode input;

  /// The video, drawn on black.
  final Widget video;

  /// While the stream starts: what it waits for. A spinner takes the play
  /// button's place meanwhile.
  final String? startupLabel;

  /// Shown above the controls when playback failed, in place of the tap layer
  /// and the spinner. The centre buttons go too: they would drive a player
  /// that failed.
  final Widget? failure;
  final Widget statsPanel;
  final ValueListenable<bool> fullscreen;
  final VoidCallback onToggleFullscreen;

  /// Open the panels from their buttons; done when they close.
  final PlayerPanelOpener onShowTracks;
  final PlayerPanelOpener onShowSettings;
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

  /// What keeps the controls on screen besides a paused player.
  final _holds = <Object>{};

  Player? _player;
  StreamSubscription<bool>? _playingSubscription;
  bool _playing = false;

  /// The offers over the video follow it once their first showing is over.
  final _visibility = ValueNotifier<bool>(true);
  bool get _controlsVisible => _visibility.value;
  set _controlsVisible(bool visible) => _visibility.value = visible;

  bool _episodesOpen = false;

  /// The panel open from the bar; its button shows it, and the controls
  /// stay while it is open.
  Object? _openPanel;
  Timer? _hideTimer;

  /// The controls' margins from the screen's edges, past a camera cutout.
  EdgeInsets _insets = EdgeInsets.zero;

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
    _visibility.dispose();
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

  bool get _touch => widget.input == PlayerInputMode.touch;

  /// The bottom controls' height once the titles finish showing or hiding.
  double get _bottomHeight =>
      _barHeight + _insets.bottom + (_playing ? 0 : _titleHeight);

  /// Where offers over the video stop, clear of the timeline and, on a
  /// narrow screen, of the buttons under it.
  double get _offerClearance =>
      _insets.bottom + math.max(_barHeight, PlayerSeekBar.height) + 24;

  /// Just above the bottom controls, with a little air.
  double get _subtitleClearanceAbove => _bottomHeight + 12;

  /// Tells the owner how much of the bottom the controls cover. The
  /// subtitles rise at once, before the titles grow under them, and come
  /// down only after the titles have collapsed.
  void _reportSubtitleClearance() {
    final report = widget.onSubtitleClearance;
    if (report == null) return;
    // A little air between the subtitles and the controls.
    final clearance = _controlsVisible && _barHeight > 0
        ? _subtitleClearanceAbove
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
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _restartHideTimer();
  }

  /// A tap on the video by touch: hides the controls at once, also while
  /// paused, or shows them for a while.
  void _toggleControls() {
    if (!_controlsVisible) {
      _showControls();
      return;
    }
    _hideTimer?.cancel();
    setState(() => _controlsVisible = false);
  }

  /// A finger on the screen keeps visible controls a while longer; showing
  /// hidden ones is the tap's to decide.
  void _onTouchDown() {
    if (_controlsVisible) _restartHideTimer();
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

  Future<void> _showPanel(
    Object panel,
    PlayerPanelOpener open,
    BuildContext anchor,
  ) async {
    if (_openPanel != null) return;
    setState(() => _openPanel = panel);
    _setHold(panel, true);
    try {
      await open(anchor);
    } finally {
      if (mounted) {
        setState(() => _openPanel = null);
        _setHold(panel, false);
      }
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
      if (widget.failure != null) return KeyEventResult.ignored;
      _togglePlay();
      _showControls();
    } else if (key == LogicalKeyboardKey.keyF && !_touch) {
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
    final metrics = _ControlsMetrics.of(widget.input);
    _insets = metrics.insets(MediaQuery.paddingOf(context));
    _reportSubtitleClearance();

    final controls = Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: visible ? MouseCursor.defer : SystemMouseCursors.none,
        onHover: (_) => _showControls(),
        child: Listener(
          onPointerDown: (_) => _touch ? _onTouchDown() : _showControls(),
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
              if (widget.failure == null) ...[
                GestureDetector(
                  key: const Key('player_immersive_tap_layer'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _touch ? _toggleControls : _togglePlay,
                  onDoubleTap: _touch ? null : widget.onToggleFullscreen,
                ),
                _BufferingSpinner(
                  engine: widget.engine,
                  color: accent,
                  startupLabel: widget.startupLabel,
                  playBox: metrics.playBox,
                ),
              ],
              IgnorePointer(
                ignoring: !visible,
                child: AnimatedOpacity(
                  key: const Key('player_immersive_controls'),
                  opacity: visible ? 1 : 0,
                  duration: _controlsFade,
                  child: player == null
                      ? const SizedBox.shrink()
                      : _buildControls(context, player, accent, metrics),
                ),
              ),
              // Above the controls: the message and its retry take the taps
              // where they are, and the controls keep the rest of the screen.
              ?widget.failure,
              _buildOffers(context),
              if (widget.chrome.notice case final notice?)
                Positioned(
                  left: _insets.left,
                  bottom: _barHeight > 0
                      ? _subtitleClearanceAbove
                      : _offerClearance,
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
        return PopScope(
          canPop: !_episodesOpen,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _closeEpisodes();
          },
          child: TooltipVisibility(visible: false, child: controls),
        );
      },
    );
  }

  Widget _buildControls(
    BuildContext context,
    Player player,
    Color accent,
    _ControlsMetrics metrics,
  ) {
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
              metrics: metrics,
              insets: _insets,
            ),
          ),
        ),
        // A failed player has nothing to play or seek; the failure stands here.
        if (widget.failure == null)
          Center(
            child: _CenterButtons(
              playing: _playing,
              engine: widget.engine,
              metrics: metrics,
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
              metrics: metrics,
              insets: _insets,
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
              openPanel: _openPanel,
              onShowTracks: (anchor) =>
                  _showPanel(#tracks, widget.onShowTracks, anchor),
              onShowSettings: (anchor) =>
                  _showPanel(#settings, widget.onShowSettings, anchor),
              onToggleFullscreen: widget.onToggleFullscreen,
              onEpisodes: widget.chrome.episodes == null ? null : _openEpisodes,
            ),
          ),
        ),
      ],
    );
  }

  /// Skip and next-episode offers sit above the timeline on the right. A
  /// pointer resting on them keeps the controls, and so the offers, up.
  Widget _buildOffers(BuildContext context) {
    final engine = widget.engine;
    final next = widget.next;

    return Positioned(
      right: _insets.right,
      bottom: _offerClearance,
      child: MouseRegion(
        onEnter: (_) => _setHold(#offers, true),
        onExit: (_) => _setHold(#offers, false),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            PlayerSkipSegmentOffer(
              segment: engine.skipSegment,
              controlsVisible: _visibility,
              fallback: _SkipForwardOffer(
                engine: engine,
                controlsVisible: _visibility,
              ),
              plate: (label, _) => _OfferButton.outlined(
                key: const Key('player_skip_segment_button'),
                label: label,
                onPressed: () => unawaited(engine.skipCurrentSegment()),
              ),
            ),
            if (next != null)
              PlayerNextOffer(
                finishing: engine.finishing,
                completed: engine.completed,
                title: next.title,
                controlsVisible: _visibility,
                plate: (label, detail) => _OfferButton.filled(
                  key: const Key('player_next_file_prompt'),
                  label: label,
                  detail: detail,
                  onPressed: next.play,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Scrims extends StatelessWidget {
  const _Scrims();

  static const _topScrimHeight = 160.0;
  static const _bottomScrimHeight = 320.0;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Both keep their full sizes while the window fits them, and shrink
          // together below their sum.
          final scale = math.min(
            1.0,
            constraints.maxHeight / (_topScrimHeight + _bottomScrimHeight),
          );
          return Column(
            children: [
              SizedBox(
                key: const Key('player_scrim_top'),
                height: _topScrimHeight * scale,
                width: double.infinity,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xB3000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                key: const Key('player_scrim_bottom'),
                height: _bottomScrimHeight * scale,
                width: double.infinity,
                child: const DecoratedBox(
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
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.chrome,
    required this.statsPanel,
    required this.metrics,
    required this.insets,
  });

  final PlayerChrome chrome;
  final Widget statsPanel;
  final _ControlsMetrics metrics;
  final EdgeInsets insets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      // The arrow's glyph starts in line with the titles and the timeline.
      padding: EdgeInsets.fromLTRB(
        insets.left - metrics.backButtonInset,
        insets.top,
        insets.right,
        insets.top,
      ),
      child: Row(
        // A first row of details sits on the arrow's axis; more rows of
        // them grow downwards.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GlyphButton(
            key: const Key('player_back_button'),
            glyph: const PixelIcon(PixelGlyph.arrowLeft),
            iconSize: 28,
            size: Size.square(metrics.backButton),
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
