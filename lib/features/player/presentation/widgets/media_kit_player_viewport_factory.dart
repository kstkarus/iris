import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:iris/features/player/presentation/widgets/media_kit_pixel_buttons.dart';
import 'package:iris/features/player/domain/entities/player_playback_diagnostics.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/playback/media_kit_player_engine.dart';
import 'package:iris/features/player/presentation/playback/player_engine.dart';
import 'package:iris/features/player/presentation/widgets/player_adaptive_layout.dart';
import 'package:iris/features/player/presentation/widgets/player_auto_hiding_offer.dart';
import 'package:iris/features/player/presentation/playback/player_buffer_margin.dart';
import 'package:iris/features/player/presentation/widgets/player_countdown.dart';
import 'package:iris/features/player/presentation/widgets/player_immersive_controls.dart';
import 'package:iris/features/player/presentation/widgets/player_overlay_preferences.dart';
import 'package:iris/features/player/presentation/widgets/player_playback_stats_indicator.dart';
import 'package:iris/features/player/presentation/widgets/player_subtitle_settings_sheet.dart';
import 'package:iris/features/player/presentation/widgets/player_track_selector_sheet.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/features/player/presentation/widgets/player_wait_indicator.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/features/player/presentation/widgets/player_offers.dart';
import 'package:iris/features/player/presentation/widgets/player_colors.dart';

export 'package:iris/features/player/presentation/playback/media_kit_player_engine.dart'
    show
        MediaKitFirstFrameAwaiter,
        MediaKitPlayerBuilder,
        MediaKitVideoControllerBuilder;

part 'media_kit/media_kit_controls_themes.dart';
part 'media_kit/player_controls_frame.dart';
part 'media_kit/player_wait_overlay.dart';
part 'media_kit/player_controls_stats_panel.dart';

typedef MediaKitVideoSurfaceBuilder =
    Widget Function({
      required VideoController controller,
      required SubtitleViewConfiguration subtitleViewConfiguration,
      required MediaKitVideoControlsThemes controlsThemes,
    });

/// Wraps the built controls, in the page and in full screen.
typedef MediaKitControlsDecorator =
    Widget Function(VideoState state, Widget controls);

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
      engine: widget.engine,
      finishing: widget.engine.finishing,
      completed: widget.engine.completed,
      nextTitle: _nextTitle,
      onPlayNext: _playNext,
      skipSegment: widget.engine.skipSegment,
      onSkip: () => unawaited(widget.engine.skipCurrentSegment()),
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
    final chrome = widget.chrome;
    if (chrome != null) return _buildImmersive(l10n, chrome);

    if (engine.startupState.phase == PlayerEnginePhase.failed) {
      return _buildFailure(l10n);
    }
    final startupLabel = _playerStartupLabel(l10n, engine);

    final videoFrame = AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: ClipRect(
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.videoSurfaceBuilder(
                controller: _controller,
                subtitleViewConfiguration: engine.subtitleViewConfiguration,
                controlsThemes: _buildControlsThemes(l10n, theme.colorScheme),
              ),
              if (startupLabel != null)
                _PlayerStartupOverlay(
                  key: const Key('player_viewport_loading_overlay'),
                  label: startupLabel,
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
    final Widget? failure;
    if (startupState.phase == PlayerEnginePhase.failed) {
      video = const SizedBox.expand();
      failure = _buildFailure(l10n);
    } else {
      video = widget.videoSurfaceBuilder(
        controller: _controller,
        subtitleViewConfiguration: engine.subtitleViewConfiguration,
        controlsThemes: MediaKitImmersiveVideoControlsThemes(
          subtitleLift: _subtitleLift,
        ),
      );
      failure = null;
    }
    return PlayerImmersiveControls(
      engine: engine,
      chrome: chrome,
      next: widget.next,
      video: video,
      failure: failure,
      startupLabel: _playerStartupLabel(l10n, engine),
      statsPanel: _buildStatsPanel(immersive: true),
      fullscreen: _windowFullscreen,
      onToggleFullscreen: _toggleWindowFullscreen,
      onSubtitleClearance: _liftSubtitles,
      onShowTracks: (anchor) => _showTrackSelectorSheet(anchor: anchor),
      onShowSettings: (anchor) => _showSettingsSheet(anchor: anchor),
    );
  }

  MediaKitVideoControlsThemes _buildControlsThemes(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final theme = _buildControlsTheme(l10n, colorScheme);
    return MediaKitMobileVideoControlsThemes(
      normal: theme,
      fullscreen: theme,
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
        // On tablets each opens its panel as a popover from itself.
        Builder(
          builder: (anchor) => MaterialCustomButton(
            key: _trackSelectorButtonKey,
            icon: _trackSelectorGlyph(l10n),
            onPressed: () => _showTrackSelectorSheet(anchor: anchor),
          ),
        ),
        Builder(
          builder: (anchor) => MaterialCustomButton(
            key: _settingsButtonKey,
            icon: _settingsGlyph(l10n),
            onPressed: () => _showSettingsSheet(anchor: anchor),
          ),
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
        engine: widget.engine,
        label: l10n.playerBuffering,
      ),
    );
  }

  static const _trackSelectorButtonKey = Key('player_track_selector_button');
  static const _settingsButtonKey = Key('player_settings_button');

  /// The tracks button of the package's control bars, named by its tooltip.
  Widget _trackSelectorGlyph(AppLocalizations l10n) => Tooltip(
    message: l10n.playerAudioAndSubtitles,
    child: const PixelIcon(PixelGlyph.subtitles, size: 21),
  );

  /// The settings button of the package's control bars, beside the tracks.
  Widget _settingsGlyph(AppLocalizations l10n) => Tooltip(
    message: l10n.playerSettingsTitle,
    child: const PixelIcon(PixelGlyph.settings, size: 21),
  );

  Future<void> _showSettingsSheet({BuildContext? anchor}) =>
      showPlayerSubtitleSettingsSheet(context, anchor: anchor);

  Future<void> _showTrackSelectorSheet({BuildContext? anchor}) async {
    final engine = widget.engine;
    if (!engine.hasPlayer) return;
    final tracks = engine.player.state.tracks;
    final selectedTrack = engine.player.state.track;

    await showPlayerAdaptiveSheet<void>(
      context: context,
      anchor: anchor,
      popoverWidth: PlayerTrackSelectorSheet.popoverWidth,
      semanticsLabel: AppLocalizations.of(context).playerAudioAndSubtitles,
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
        );
      },
    );
  }
}

/// What the player waits for before the picture shows, or null once it
/// does; the same in every layout.
String? _playerStartupLabel(
  AppLocalizations l10n,
  MediaKitPlayerEngine engine,
) {
  final state = engine.startupState;
  return switch (state.phase) {
    PlayerEnginePhase.failed => null,
    PlayerEnginePhase.openingSource => l10n.playerPreparing,
    PlayerEnginePhase.waitingForFirstFrame => l10n.playerBuffering,
    // Ready can come from the file's header alone; the stream may take
    // seconds more to show a picture, and a black screen would hide it.
    PlayerEnginePhase.ready =>
      engine.reconfiguring || !state.firstFrameRendered
          ? l10n.playerBuffering
          : null,
  };
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
    // Its controls draw nothing; they keep the Flutter subtitles (no
    // libass) clear of the immersive controls.
    MediaKitImmersiveVideoControlsThemes() => video,
  };
}
