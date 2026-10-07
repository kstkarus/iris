import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:iris/features/player/presentation/widgets/media_kit_pixel_buttons.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/playback/media_kit_player_engine.dart';
import 'package:iris/features/player/presentation/playback/player_engine.dart';
import 'package:iris/features/player/presentation/widgets/player_adaptive_layout.dart';
import 'package:iris/features/player/presentation/widgets/player_auto_hiding_offer.dart';
import 'package:iris/features/player/presentation/widgets/player_buffer_health_tracker.dart';
import 'package:iris/features/player/presentation/widgets/player_immersive_controls.dart';
import 'package:iris/features/player/presentation/widgets/player_overlay_preferences.dart';
import 'package:iris/features/player/presentation/widgets/player_playback_stats_indicator.dart';
import 'package:iris/features/player/presentation/widgets/player_subtitle_settings_sheet.dart';
import 'package:iris/features/player/presentation/widgets/player_track_selector_sheet.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/features/player/presentation/widgets/player_wait_indicator.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

export 'package:iris/features/player/presentation/playback/media_kit_player_engine.dart'
    show
        MediaKitFirstFrameAwaiter,
        MediaKitPlayerBuilder,
        MediaKitVideoControllerBuilder;

typedef MediaKitVideoSurfaceBuilder =
    Widget Function({
      required VideoController controller,
      required SubtitleViewConfiguration subtitleViewConfiguration,
      required MediaKitVideoControlsThemes controlsThemes,
    });

/// Wraps the built controls, in the page and in full screen.
typedef MediaKitControlsDecorator =
    Widget Function(VideoState state, Widget controls);

/// Video controls flavour and its themes, chosen per platform.
///
/// Touch platforms use [MaterialVideoControls]; desktop platforms use
/// [MaterialDesktopVideoControls] (mouse hover, keyboard shortcuts).
sealed class MediaKitVideoControlsThemes {
  const MediaKitVideoControlsThemes();

  List<Widget> get topButtonBar;

  VideoControlsBuilder get controlsBuilder;

  MediaKitControlsDecorator? get decorateControls;

  /// [controlsBuilder] wrapped by [decorateControls].
  VideoControlsBuilder get controls => (state) {
    final controls = controlsBuilder(state);
    return decorateControls?.call(state, controls) ?? controls;
  };
}

final class MediaKitMobileVideoControlsThemes
    extends MediaKitVideoControlsThemes {
  const MediaKitMobileVideoControlsThemes({
    required this.normal,
    required this.fullscreen,
    this.decorateControls,
  });

  final MaterialVideoControlsThemeData normal;
  final MaterialVideoControlsThemeData fullscreen;

  @override
  final MediaKitControlsDecorator? decorateControls;

  @override
  List<Widget> get topButtonBar => normal.topButtonBar;

  @override
  VideoControlsBuilder get controlsBuilder => MaterialVideoControls;
}

final class MediaKitDesktopVideoControlsThemes
    extends MediaKitVideoControlsThemes {
  const MediaKitDesktopVideoControlsThemes({
    required this.normal,
    required this.fullscreen,
    this.decorateControls,
  });

  final MaterialDesktopVideoControlsThemeData normal;
  final MaterialDesktopVideoControlsThemeData fullscreen;

  @override
  final MediaKitControlsDecorator? decorateControls;

  @override
  List<Widget> get topButtonBar => normal.topButtonBar;

  @override
  VideoControlsBuilder get controlsBuilder => MaterialDesktopVideoControls;
}

/// No media_kit controls: [PlayerImmersiveControls] are drawn over the
/// video instead.
final class MediaKitImmersiveVideoControlsThemes
    extends MediaKitVideoControlsThemes {
  const MediaKitImmersiveVideoControlsThemes({required this.subtitleLift});

  /// Pixels kept clear at the bottom of the Flutter subtitle view.
  final ValueListenable<double> subtitleLift;

  @override
  List<Widget> get topButtonBar => const [];

  /// Draws nothing; only moves the Flutter subtitle view, which belongs to
  /// the [VideoState].
  @override
  VideoControlsBuilder get controlsBuilder =>
      (state) => _SubtitleLift(video: state, lift: subtitleLift);

  @override
  MediaKitControlsDecorator? get decorateControls => null;
}

/// Switches the native window in or out of full screen.
typedef NativeFullscreenToggle = Future<void> Function();

class MediaKitPlayerViewportFactory implements PlayerViewportFactory {
  MediaKitPlayerViewportFactory({
    required PlayerRepository repository,
    MediaKitPlayerBuilder? playerBuilder,
    MediaKitVideoControllerBuilder? videoControllerBuilder,
    MediaKitFirstFrameAwaiter? firstFrameAwaiter,
    MediaKitVideoSurfaceBuilder? videoSurfaceBuilder,
    Duration mediaKitStartupTimeout = const Duration(seconds: 45),
    NativeFullscreenToggle enterNativeFullscreen = defaultEnterNativeFullscreen,
    NativeFullscreenToggle exitNativeFullscreen = defaultExitNativeFullscreen,
  }) : _repository = repository,
       _enterNativeFullscreen = enterNativeFullscreen,
       _exitNativeFullscreen = exitNativeFullscreen,
       _playerBuilder = playerBuilder,
       _videoControllerBuilder = videoControllerBuilder,
       _firstFrameAwaiter = firstFrameAwaiter,
       _videoSurfaceBuilder =
           videoSurfaceBuilder ?? _defaultVideoSurfaceBuilder,
       _mediaKitStartupTimeout = mediaKitStartupTimeout;

  final PlayerRepository _repository;
  final MediaKitPlayerBuilder? _playerBuilder;
  final MediaKitVideoControllerBuilder? _videoControllerBuilder;
  final MediaKitFirstFrameAwaiter? _firstFrameAwaiter;
  final MediaKitVideoSurfaceBuilder _videoSurfaceBuilder;
  final Duration _mediaKitStartupTimeout;
  final NativeFullscreenToggle _enterNativeFullscreen;
  final NativeFullscreenToggle _exitNativeFullscreen;

  @override
  MediaKitPlayerEngine createEngine({
    required PlayerSubtitlePreferencesCubit subtitlePreferences,
    required PlayerDecodingPreferencesCubit decodingPreferences,
  }) {
    return MediaKitPlayerEngine(
      repository: _repository,
      subtitlePreferences: subtitlePreferences,
      decodingPreferences: decodingPreferences,
      playerBuilder: _playerBuilder,
      videoControllerBuilder: _videoControllerBuilder,
      firstFrameAwaiter: _firstFrameAwaiter,
      startupTimeout: _mediaKitStartupTimeout,
    );
  }

  @override
  Widget build({
    required PlayerEngine engine,
    PlayerNextFile? next,
    PlayerChrome? chrome,
  }) {
    return _MediaKitPlayerViewport(
      engine: engine as MediaKitPlayerEngine,
      next: next,
      chrome: chrome,
      videoSurfaceBuilder: _videoSurfaceBuilder,
      enterNativeFullscreen: _enterNativeFullscreen,
      exitNativeFullscreen: _exitNativeFullscreen,
    );
  }
}

class _MediaKitPlayerViewport extends StatefulWidget {
  const _MediaKitPlayerViewport({
    required this.engine,
    required this.next,
    required this.chrome,
    required this.videoSurfaceBuilder,
    required this.enterNativeFullscreen,
    required this.exitNativeFullscreen,
  });

  final MediaKitPlayerEngine engine;
  final PlayerNextFile? next;
  final PlayerChrome? chrome;
  final MediaKitVideoSurfaceBuilder videoSurfaceBuilder;
  final NativeFullscreenToggle enterNativeFullscreen;
  final NativeFullscreenToggle exitNativeFullscreen;

  @override
  State<_MediaKitPlayerViewport> createState() =>
      _MediaKitPlayerViewportState();
}

class _MediaKitPlayerViewportState extends State<_MediaKitPlayerViewport> {
  late VideoController _controller = widget.engine.videoController;

  /// The full-screen route keeps the controls it was opened with, so they
  /// read the next file's title from here.
  late final _nextTitle = ValueNotifier<String?>(widget.next?.title);

  /// The full-screen route showing this player, while it is open.
  ModalRoute<Object?>? _fullscreenRoute;

  /// Full screen closed for a replaced native player, to reopen with the
  /// new one.
  bool _reenterFullscreen = false;

  /// The immersive player's window full screen; it has no route of its own.
  final _windowFullscreen = ValueNotifier<bool>(false);

  /// Room the immersive controls take at the bottom, for the subtitles.
  final _subtitleLift = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    widget.engine.addListener(_onEngineChanged);
  }

  @override
  void didUpdateWidget(covariant _MediaKitPlayerViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextTitle = widget.next?.title;
    if (nextTitle != _nextTitle.value) {
      // The full-screen controls are not below this widget; they must not be
      // marked dirty while it builds.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nextTitle.value = widget.next?.title;
      });
    }
    if (oldWidget.engine != widget.engine) {
      oldWidget.engine.removeListener(_onEngineChanged);
      widget.engine.addListener(_onEngineChanged);
      _controller = widget.engine.videoController;
    }
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngineChanged);
    _closeFullscreen();
    if (_windowFullscreen.value) unawaited(widget.exitNativeFullscreen());
    _windowFullscreen.dispose();
    _subtitleLift.dispose();
    _nextTitle.dispose();
    super.dispose();
  }

  void _onEngineChanged() {
    if (!mounted) return;
    final controller = widget.engine.videoController;
    if (!identical(controller, _controller)) {
      // Full screen renders the controller it was opened with; a new native
      // player (changed decoding preferences) needs it reopened.
      if (_closeFullscreen()) _reenterFullscreen = true;
      _controller = controller;
    }
    setState(() {});
  }

  /// Closes a full-screen route left open by this player. Returns whether
  /// there was one.
  bool _closeFullscreen() {
    final route = _fullscreenRoute;
    _fullscreenRoute = null;
    if (route == null || !route.isActive) return false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isCurrent) {
        // A pop (unlike removeRoute) also leaves native full screen.
        unawaited(route.navigator?.maybePop());
      } else if (route.isActive) {
        route.navigator?.removeRoute(route);
      }
    });
    return true;
  }

  void _onInlineControlsShown(VideoState video) {
    if (!_reenterFullscreen) return;
    _reenterFullscreen = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && video.mounted && !video.isFullscreen()) {
        unawaited(video.enterFullscreen());
      }
    });
  }

  void _playNext() => widget.next?.play();

  /// Moves the subtitles above [clearance] pixels of controls at the
  /// bottom of a [viewSize] box the video is fitted into.
  void _liftSubtitles(double clearance, Size viewSize) {
    _subtitleLift.value = clearance;
    final engine = widget.engine;
    if (!engine.hasPlayer) return;
    // mpv places its subtitles relative to the video, not the box.
    final state = engine.player.state;
    var videoHeight = viewSize.height;
    final width = state.width;
    final height = state.height;
    if (width != null && height != null && width > 0 && height > 0) {
      videoHeight = (viewSize.width * height / width).clamp(
        0.0,
        viewSize.height,
      );
    }
    if (videoHeight <= 0) return;
    final belowVideo = (viewSize.height - videoHeight) / 2;
    final lift = (clearance - belowVideo).clamp(0.0, videoHeight);
    unawaited(engine.liftSubtitles(lift / videoHeight));
  }

  void _toggleWindowFullscreen() {
    final enter = !_windowFullscreen.value;
    _windowFullscreen.value = enter;
    unawaited(
      enter ? widget.enterNativeFullscreen() : widget.exitNativeFullscreen(),
    );
  }

  Widget _decorateControls(VideoState video, Widget controls) {
    return _PlayerControlsFrame(
      phase: widget.engine.phase,
      finishing: widget.engine.finishing,
      completed: widget.engine.completed,
      nextTitle: _nextTitle,
      onPlayNext: _playNext,
      skipSegment: widget.engine.skipSegment,
      onSkip: () => unawaited(widget.engine.skipCurrentSegment()),
      openingLabel: AppLocalizations.of(context).playerPreparing,
      bufferingLabel: AppLocalizations.of(context).playerBuffering,
      stats: widget.engine.playbackStats,
      onFullscreenRoute: (route) => _fullscreenRoute = route,
      onInlineShown: () => _onInlineControlsShown(video),
      child: controls,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final engine = widget.engine;
    final startupState = engine.startupState;
    final chrome = widget.chrome;
    if (chrome != null) return _buildImmersive(l10n, chrome);

    if (startupState.phase == PlayerEnginePhase.failed) {
      return _buildFailure(l10n);
    }

    final videoFrame = AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.zero,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.videoSurfaceBuilder(
                controller: _controller,
                subtitleViewConfiguration: engine.subtitleViewConfiguration,
                controlsThemes: _buildControlsThemes(l10n, theme.colorScheme),
              ),
              if (engine.reconfiguring ||
                  startupState.phase != PlayerEnginePhase.ready)
                _PlayerStartupOverlay(
                  key: const Key('player_viewport_loading_overlay'),
                  label: startupState.phase == PlayerEnginePhase.openingSource
                      ? l10n.playerPreparing
                      : l10n.playerBuffering,
                  stats: engine.playbackStats,
                ),
            ],
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return videoFrame;

        // The 16:9 frame fills the available space; mpv letterboxes
        // non-16:9 content inside it. The title lives in the app bar.
        // Top-aligned so the video lines up with the page and the episodes
        // pane headings.
        return Align(alignment: Alignment.topCenter, child: videoFrame);
      },
    );
  }

  Widget _buildFailure(AppLocalizations l10n) {
    final engine = widget.engine;
    final errorMessage =
        engine.startupState.failure == PlayerEngineFailure.firstFrameTimeout
        ? l10n.playerUnableToPrepareFirstFrame
        : l10n.playerUnableToStart;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => unawaited(engine.retry()),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }

  /// The video fills the box; the immersive controls lie over it.
  Widget _buildImmersive(AppLocalizations l10n, PlayerChrome chrome) {
    final engine = widget.engine;
    final startupState = engine.startupState;
    final Widget video;
    if (startupState.phase == PlayerEnginePhase.failed) {
      video = _buildFailure(l10n);
    } else {
      video = widget.videoSurfaceBuilder(
        controller: _controller,
        subtitleViewConfiguration: engine.subtitleViewConfiguration,
        controlsThemes: MediaKitImmersiveVideoControlsThemes(
          subtitleLift: _subtitleLift,
        ),
      );
    }
    final String? startupLabel;
    if (startupState.phase == PlayerEnginePhase.failed) {
      startupLabel = null;
    } else if (startupState.phase == PlayerEnginePhase.openingSource) {
      startupLabel = l10n.playerPreparing;
    } else if (engine.reconfiguring ||
        startupState.phase != PlayerEnginePhase.ready ||
        // Ready can come from the file's header alone; the stream may take
        // seconds more to show a picture, and a black screen would hide it.
        !startupState.firstFrameRendered) {
      startupLabel = l10n.playerBuffering;
    } else {
      startupLabel = null;
    }

    return PlayerImmersiveControls(
      engine: engine,
      chrome: chrome,
      next: widget.next,
      video: video,
      startupLabel: startupLabel,
      statsPanel: _buildStatsPanel(immersive: true),
      fullscreen: _windowFullscreen,
      onToggleFullscreen: _toggleWindowFullscreen,
      onSubtitleClearance: _liftSubtitles,
      onShowTracks: () => unawaited(_showTrackSelectorSheet()),
      onShowSettings: () => unawaited(showPlayerSubtitleSettingsSheet(context)),
    );
  }

  MediaKitVideoControlsThemes _buildControlsThemes(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    if (isDesktopPlayerPlatform()) {
      final desktopTheme = _buildDesktopControlsTheme(l10n, colorScheme);
      return MediaKitDesktopVideoControlsThemes(
        normal: desktopTheme,
        fullscreen: desktopTheme,
        decorateControls: _decorateControls,
      );
    }

    return MediaKitMobileVideoControlsThemes(
      normal: _buildControlsTheme(l10n, colorScheme),
      fullscreen: _buildControlsTheme(l10n, colorScheme),
      decorateControls: _decorateControls,
    );
  }

  Widget _buildStatsPanel({bool immersive = false}) {
    final engine = widget.engine;
    return Flexible(
      fit: FlexFit.loose,
      child: Align(
        alignment: Alignment.centerLeft,
        // As tall as the stats, not the row: the immersive top bar has no
        // fixed height.
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: immersive ? 640 : 280),
          child: _PlayerControlsStatsPanel(
            immersive: immersive,
            listenable: engine.playbackStats,
            diagnosticsListenable: engine.diagnostics,
            startupPhaseListenable: engine.phase,
            trackListenable: engine.selectedTrack,
            bufferMarginStateListenable: engine.bufferMargin,
            isBufferingListenable: engine.buffering,
          ),
        ),
      ),
    );
  }

  /// Desktop controls: hover shows/hides the bars, double-click toggles
  /// fullscreen, mouse wheel changes volume. The package default keyboard
  /// shortcuts stay active: Space play/pause, Left/Right seek, Up/Down volume,
  /// F fullscreen, Esc exit fullscreen.
  MaterialDesktopVideoControlsThemeData _buildDesktopControlsTheme(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return MaterialDesktopVideoControlsThemeData(
      topButtonBar: [
        _buildStatsPanel(),
        const SizedBox(width: 8),
        MaterialDesktopCustomButton(
          key: _trackSelectorButtonKey,
          icon: _trackSelectorGlyph(l10n),
          iconSize: 24,
          onPressed: _showTrackSelectorSheet,
        ),
      ],
      bottomButtonBar: [
        const MaterialDesktopPlayOrPauseButton(),
        if (widget.next != null)
          MaterialDesktopCustomButton(
            key: const Key('player_next_file_button'),
            icon: Tooltip(
              message: l10n.playerPlayNext,
              child: const PixelIcon(PixelGlyph.skipNext, size: 21),
            ),
            iconSize: 24,
            onPressed: _playNext,
          ),
        const MaterialDesktopVolumeButton(),
        const MaterialDesktopPositionIndicator(),
        const Spacer(),
        _skipForwardButton(l10n),
        const MaterialDesktopFullscreenButton(),
      ],
      toggleFullscreenOnDoublePress: true,
      modifyVolumeOnScroll: true,
      hideMouseOnControlsRemoval: true,
      buttonBarButtonSize: 24,
      seekBarPositionColor: playerAccentColor(colorScheme),
      seekBarThumbColor: playerAccentColor(colorScheme),
      bufferingIndicatorBuilder: (context) => _PlayerControlsBufferingOverlay(
        startupPhaseListenable: widget.engine.phase,
        label: l10n.playerBuffering,
      ),
    );
  }

  /// "+85 s" while the opening is unknown and the file has just started;
  /// part of the controls, so it hides with them.
  Widget _skipForwardButton(AppLocalizations l10n) {
    final seconds = MediaKitPlayerEngine.skipForwardStep.inSeconds;
    return ValueListenableBuilder<bool>(
      valueListenable: widget.engine.skipForwardOffered,
      builder: (context, offered, _) {
        if (!offered) return const SizedBox.shrink();
        return Tooltip(
          message: l10n.playerSkipForwardTooltip(seconds),
          // "+85 s" names the action; no glyph needed beside it.
          child: TextButton(
            key: const Key('player_skip_forward_button'),
            onPressed: () => unawaited(widget.engine.skipForward()),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: Text(l10n.playerSkipForward(seconds)),
          ),
        );
      },
    );
  }

  Widget? _nextButton(AppLocalizations l10n, {Key? key}) {
    if (widget.next == null) return null;
    return MaterialCustomButton(
      key: key,
      icon: Tooltip(
        message: l10n.playerPlayNext,
        child: const PixelIcon(PixelGlyph.skipNext, size: 28),
      ),
      iconSize: 36,
      onPressed: _playNext,
    );
  }

  MaterialVideoControlsThemeData _buildControlsTheme(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return MaterialVideoControlsThemeData(
      primaryButtonBar: [
        const Spacer(),
        // An invisible twin keeps play/pause centred.
        if (_nextButton(l10n) case final next?)
          Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: next,
          ),
        const PixelPlayOrPauseButton(),
        ?_nextButton(l10n, key: const Key('player_next_file_button')),
        const Spacer(),
      ],
      topButtonBar: [
        _buildStatsPanel(),
        const SizedBox(width: 8),
        MaterialCustomButton(
          key: _trackSelectorButtonKey,
          icon: _trackSelectorGlyph(l10n),
          onPressed: _showTrackSelectorSheet,
        ),
      ],
      bottomButtonBar: [
        const MaterialPositionIndicator(),
        const Spacer(),
        _skipForwardButton(l10n),
        const PixelFullscreenButton(),
      ],
      seekBarPositionColor: playerAccentColor(colorScheme),
      seekBarThumbColor: playerAccentColor(colorScheme),
      volumeGesture: true,
      brightnessGesture: true,
      seekGesture: true,
      seekOnDoubleTap: true,
      bufferingIndicatorBuilder: (context) => _PlayerControlsBufferingOverlay(
        startupPhaseListenable: widget.engine.phase,
        label: l10n.playerBuffering,
      ),
    );
  }

  static const _trackSelectorButtonKey = Key('player_track_selector_button');

  /// The tracks button of the package's control bars, named by its tooltip.
  Widget _trackSelectorGlyph(AppLocalizations l10n) => Tooltip(
    message: l10n.playerAudioAndSubtitles,
    child: const PixelIcon(PixelGlyph.tune, size: 21),
  );

  Future<void> _showTrackSelectorSheet() async {
    final engine = widget.engine;
    if (!engine.hasPlayer) return;
    final tracks = engine.player.state.tracks;
    final selectedTrack = engine.player.state.track;

    await showPlayerAdaptiveSheet<void>(
      context: context,
      builder: (sheetContext) {
        return PlayerTrackSelectorSheet(
          audioTracks: tracks.audio,
          selectedAudioTrack: selectedTrack.audio,
          subtitleTracks: tracks.subtitle,
          selectedSubtitleTrack: selectedTrack.subtitle,
          onAudioTrackSelected: (track) async {
            await engine.selectAudioTrack(track);
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          },
          onSubtitleTrackSelected: (track) async {
            await engine.selectSubtitleTrack(track);
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          },
          onSubtitleAppearancePressed: () {
            Navigator.of(sheetContext).pop();
            unawaited(showPlayerSubtitleSettingsSheet(context));
          },
        );
      },
    );
  }
}

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
  late final _nextState = Listenable.merge([
    widget.finishing,
    widget.completed,
    widget.nextTitle,
  ]);

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
    final l10n = AppLocalizations.of(context);
    final fullscreen = isFullscreen(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerHover: (_) => _activity.ping(),
      onPointerDown: (_) => _activity.ping(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          ValueListenableBuilder<PlayerSkipSegment?>(
            valueListenable: widget.skipSegment,
            builder: (context, segment, _) {
              if (segment == null) return const SizedBox.shrink();
              return PlayerAutoHidingOffer(
                key: ValueKey(segment),
                activity: _activity,
                child: _PlayerActionPill(
                  actionKey: const Key('player_skip_segment_button'),
                  label: segment.kind == PlayerSkipKind.recap
                      ? l10n.playerSkipRecap
                      : l10n.playerSkipOpening,
                  onPressed: widget.onSkip,
                ),
              );
            },
          ),
          ListenableBuilder(
            listenable: _nextState,
            builder: (context, _) {
              final title = widget.nextTitle.value;
              final completed = widget.completed.value;
              if (title == null || !(widget.finishing.value || completed)) {
                return const SizedBox.shrink();
              }
              return PlayerAutoHidingOffer(
                activity: _activity,
                // Once the file has ended there is nothing left to cover.
                pinned: completed,
                child: _PlayerActionPill(
                  actionKey: const Key('player_next_file_prompt'),
                  label: l10n.playerPlayNext,
                  detail: title,
                  onPressed: widget.onPlayNext,
                ),
              );
            },
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
    final detail = this.detail;
    return Align(
      alignment: AlignmentDirectional.bottomEnd,
      child: Padding(
        // Clear of the bottom button bar and the seek bar.
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 72),
        child: FilledButton(
          key: actionKey,
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                if (detail != null)
                  // Inherits the button's colour.
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
          ),
        ),
      ),
    );
  }
}

/// Keeps the Flutter subtitle view above [lift] pixels of controls.
class _SubtitleLift extends StatefulWidget {
  const _SubtitleLift({required this.video, required this.lift});

  final VideoState video;
  final ValueListenable<double> lift;

  @override
  State<_SubtitleLift> createState() => _SubtitleLiftState();
}

class _SubtitleLiftState extends State<_SubtitleLift> {
  @override
  void initState() {
    super.initState();
    widget.lift.addListener(_apply);
    // The subtitle view mounts in the same frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
  }

  @override
  void didUpdateWidget(covariant _SubtitleLift oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lift != widget.lift) {
      oldWidget.lift.removeListener(_apply);
      widget.lift.addListener(_apply);
    }
  }

  @override
  void dispose() {
    widget.lift.removeListener(_apply);
    super.dispose();
  }

  void _apply() {
    if (!mounted || !widget.video.mounted) return;
    final base = widget.video.widget.subtitleViewConfiguration.padding;
    widget.video.setSubtitleViewPadding(
      base.copyWith(bottom: base.bottom + widget.lift.value),
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _BufferingIndicator extends StatelessWidget {
  const _BufferingIndicator({required this.label, this.stats});

  final String label;
  final ValueListenable<PlayerPlaybackStats?>? stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BlockRunner(
          color: playerAccentColor(Theme.of(context).colorScheme),
          trackColor: Colors.white24,
        ),
        const SizedBox(height: 12),
        PlayerWaitLabel(
          label: label,
          stats: stats,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}

class _PlayerStartupOverlay extends StatelessWidget {
  const _PlayerStartupOverlay({
    required this.label,
    required this.stats,
    super.key,
  });

  final String label;
  final ValueListenable<PlayerPlaybackStats?> stats;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _BufferingIndicator(label: label, stats: stats),
        ),
      ),
    );
  }
}

class _PlayerControlsStatsPanel extends StatelessWidget {
  const _PlayerControlsStatsPanel({
    required this.immersive,
    required this.listenable,
    required this.diagnosticsListenable,
    required this.startupPhaseListenable,
    required this.trackListenable,
    required this.bufferMarginStateListenable,
    required this.isBufferingListenable,
  });

  final ValueListenable<PlayerPlaybackStats?> listenable;
  final ValueListenable<PlayerPlaybackDiagnostics?> diagnosticsListenable;
  final ValueListenable<PlayerEnginePhase> startupPhaseListenable;
  final ValueListenable<Track> trackListenable;
  final ValueListenable<PlayerBufferMarginState> bufferMarginStateListenable;
  final ValueListenable<bool> isBufferingListenable;
  final bool immersive;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        startupPhaseListenable,
        trackListenable,
        bufferMarginStateListenable,
        isBufferingListenable,
        playerDetailedStatsEnabled,
      ]),
      builder: (context, child) {
        if (startupPhaseListenable.value != PlayerEnginePhase.ready) {
          return const SizedBox.shrink();
        }
        // Over a full-bleed video the numbers show up when they explain
        // something: a stall, a thin buffer, or when asked for.
        final detailed = playerDetailedStatsEnabled.value;
        final buffering = isBufferingListenable.value;
        final bufferMargin = bufferMarginStateListenable.value;
        if (immersive &&
            !detailed &&
            !buffering &&
            bufferMargin != PlayerBufferMarginState.insufficient) {
          return const SizedBox.shrink();
        }

        final track = trackListenable.value;
        return PlayerPlaybackStatsListenable(
          listenable: listenable,
          videoCodec: track.video.codec,
          audioCodec: track.audio.codec,
          diagnosticsListenable: diagnosticsListenable,
          bufferMarginState: bufferMargin,
          isBuffering: buffering,
          detailed: detailed,
          immersive: immersive,
        );
      },
    );
  }
}

class _PlayerControlsBufferingOverlay extends StatelessWidget {
  const _PlayerControlsBufferingOverlay({
    required this.startupPhaseListenable,
    required this.label,
  });

  final ValueListenable<PlayerEnginePhase> startupPhaseListenable;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayerEnginePhase>(
      valueListenable: startupPhaseListenable,
      builder: (context, phase, child) {
        if (phase != PlayerEnginePhase.ready) {
          return const SizedBox.shrink();
        }

        return _BufferingIndicator(label: label);
      },
    );
  }
}

Widget _defaultVideoSurfaceBuilder({
  required VideoController controller,
  required SubtitleViewConfiguration subtitleViewConfiguration,
  required MediaKitVideoControlsThemes controlsThemes,
}) {
  final video = Video(
    key: const Key('player_video_surface'),
    controller: controller,
    controls: controlsThemes.controls,
    subtitleViewConfiguration: subtitleViewConfiguration,
  );

  return switch (controlsThemes) {
    MediaKitMobileVideoControlsThemes(:final normal, :final fullscreen) =>
      MaterialVideoControlsTheme(
        normal: normal,
        fullscreen: fullscreen,
        child: video,
      ),
    MediaKitDesktopVideoControlsThemes(:final normal, :final fullscreen) =>
      MaterialDesktopVideoControlsTheme(
        normal: normal,
        fullscreen: fullscreen,
        child: video,
      ),
    MediaKitImmersiveVideoControlsThemes() => Video(
      key: const Key('player_video_surface'),
      controller: controller,
      controls: NoVideoControls,
      subtitleViewConfiguration: subtitleViewConfiguration,
    ),
  };
}
