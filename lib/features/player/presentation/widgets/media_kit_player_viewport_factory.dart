import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:iris/features/online_sources/domain/repositories/online_quality_preferences.dart';
import 'package:iris/features/player/domain/entities/player_playback_diagnostics.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/playback/media_kit_player_engine.dart';
import 'package:iris/features/player/presentation/playback/player_engine.dart';
import 'package:iris/features/player/presentation/widgets/player_adaptive_layout.dart';
import 'package:iris/features/player/presentation/playback/player_buffer_margin.dart';
import 'package:iris/features/player/presentation/widgets/player_immersive_controls.dart';
import 'package:iris/features/player/presentation/widgets/player_overlay_preferences.dart';
import 'package:iris/features/player/presentation/widgets/player_playback_stats_indicator.dart';
import 'package:iris/features/player/presentation/widgets/player_subtitle_settings_sheet.dart';
import 'package:iris/features/player/presentation/widgets/player_track_selector_sheet.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/window/picture_in_picture.dart';
import 'package:iris/shared/window/screen_brightness_control.dart';

export 'package:iris/features/player/presentation/playback/media_kit_player_engine.dart'
    show
        MediaKitFirstFrameAwaiter,
        MediaKitPlayerBuilder,
        MediaKitVideoControllerBuilder;

part 'media_kit/picture_in_picture_link.dart';
part 'media_kit/fitted_video.dart';
part 'media_kit/player_controls_stats_panel.dart';

/// Builds the video itself, the whole of it in its box and nothing over
/// it: the viewport zooms it to fill the screen and draws the subtitles.
typedef MediaKitVideoSurfaceBuilder =
    Widget Function({required VideoController controller});

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
    ScreenBrightnessControl? brightness,
    PictureInPicture? pictureInPicture,
    OnlineQualityPreferences? onlineQuality,
  }) : _repository = repository,
       _onlineQuality = onlineQuality,
       _brightness = brightness,
       _pictureInPicture = pictureInPicture,
       _enterNativeFullscreen = enterNativeFullscreen,
       _exitNativeFullscreen = exitNativeFullscreen,
       _playerBuilder = playerBuilder,
       _videoControllerBuilder = videoControllerBuilder,
       _firstFrameAwaiter = firstFrameAwaiter,
       _videoSurfaceBuilder =
           videoSurfaceBuilder ?? _defaultVideoSurfaceBuilder,
       _mediaKitStartupTimeout = mediaKitStartupTimeout;

  final PlayerRepository _repository;
  final OnlineQualityPreferences? _onlineQuality;
  final MediaKitPlayerBuilder? _playerBuilder;
  final MediaKitVideoControllerBuilder? _videoControllerBuilder;
  final MediaKitFirstFrameAwaiter? _firstFrameAwaiter;
  final MediaKitVideoSurfaceBuilder _videoSurfaceBuilder;
  final Duration _mediaKitStartupTimeout;
  final NativeFullscreenToggle _enterNativeFullscreen;
  final NativeFullscreenToggle _exitNativeFullscreen;

  /// The screen's brightness by touch; null where there is none to set
  /// (desktop), and the player shows no slider.
  final ScreenBrightnessControl? _brightness;

  /// The small window over other apps; null where there is none, and the
  /// player shows no button for it.
  final PictureInPicture? _pictureInPicture;

  @override
  MediaKitPlayerEngine createEngine({
    required PlayerSubtitlePreferencesCubit subtitlePreferences,
    required PlayerDecodingPreferencesCubit decodingPreferences,
  }) {
    return MediaKitPlayerEngine(
      repository: _repository,
      subtitlePreferences: subtitlePreferences,
      decodingPreferences: decodingPreferences,
      onlineQuality: _onlineQuality,
      playerBuilder: _playerBuilder,
      videoControllerBuilder: _videoControllerBuilder,
      firstFrameAwaiter: _firstFrameAwaiter,
      startupTimeout: _mediaKitStartupTimeout,
    );
  }

  @override
  Widget build({
    required PlayerEngine engine,
    required PlayerChrome chrome,
    PlayerInputMode input = PlayerInputMode.pointer,
    PlayerNextFile? next,
  }) {
    return _MediaKitPlayerViewport(
      engine: engine as MediaKitPlayerEngine,
      next: next,
      chrome: chrome,
      input: input,
      videoSurfaceBuilder: _videoSurfaceBuilder,
      enterNativeFullscreen: _enterNativeFullscreen,
      exitNativeFullscreen: _exitNativeFullscreen,
      brightness: _brightness,
      pictureInPicture: _pictureInPicture,
    );
  }
}

class _MediaKitPlayerViewport extends StatefulWidget {
  const _MediaKitPlayerViewport({
    required this.engine,
    required this.next,
    required this.chrome,
    required this.input,
    required this.videoSurfaceBuilder,
    required this.enterNativeFullscreen,
    required this.exitNativeFullscreen,
    required this.brightness,
    required this.pictureInPicture,
  });

  final MediaKitPlayerEngine engine;
  final PlayerNextFile? next;
  final PlayerChrome chrome;
  final PlayerInputMode input;
  final MediaKitVideoSurfaceBuilder videoSurfaceBuilder;
  final NativeFullscreenToggle enterNativeFullscreen;
  final NativeFullscreenToggle exitNativeFullscreen;
  final ScreenBrightnessControl? brightness;
  final PictureInPicture? pictureInPicture;

  @override
  State<_MediaKitPlayerViewport> createState() =>
      _MediaKitPlayerViewportState();
}

class _MediaKitPlayerViewportState extends State<_MediaKitPlayerViewport> {
  late VideoController _controller = widget.engine.videoController;

  /// The window's full screen, switched from the controls with a pointer;
  /// phones stay full screen while the player page is open.
  final _windowFullscreen = ValueNotifier<bool>(false);

  /// Room the controls take at the bottom, for the subtitles.
  final _subtitleLift = ValueNotifier<double>(0);

  /// The subtitles Flutter draws (no libass); a new controller gets a new
  /// view, which follows its player.
  var _subtitleKey = GlobalKey<SubtitleViewState>();

  /// The subtitle padding last lifted from; another (the settings changed)
  /// is lifted again.
  EdgeInsets? _subtitleBase;

  /// The whole video in the box, or the box filled with it (a pinch).
  final _videoFit = ValueNotifier<BoxFit>(BoxFit.contain);

  /// The controls' last report, to place the subtitles again when the fit
  /// changes.
  double _clearance = 0;
  Size? _viewSize;

  /// Keeps the small window told what plays; null without one.
  _PictureInPictureLink? _pictureInPicture;

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _onAppHidden);
    _subtitleLift.addListener(_applySubtitleLift);
    widget.engine.addListener(_onEngineChanged);
    _videoFit.addListener(_onVideoFitChanged);
    final pictureInPicture = widget.pictureInPicture;
    if (pictureInPicture != null) {
      _pictureInPicture = _PictureInPictureLink(
        pictureInPicture,
        engine: widget.engine,
        onSupported: () {
          if (mounted) setState(() {});
        },
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context);
    _pictureInPicture?.labels = (
      play: l10n.playerPlayButton,
      pause: l10n.playerPauseButton,
    );
  }

  @override
  void didUpdateWidget(covariant _MediaKitPlayerViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engine != widget.engine) {
      oldWidget.engine.removeListener(_onEngineChanged);
      widget.engine.addListener(_onEngineChanged);
      _followController();
      _pictureInPicture?.engine = widget.engine;
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    widget.engine.removeListener(_onEngineChanged);
    _pictureInPicture?.dispose();
    if (_windowFullscreen.value) unawaited(widget.exitNativeFullscreen());
    // The system's brightness again once the video is gone.
    final brightness = widget.brightness;
    if (brightness != null) unawaited(brightness.reset());
    _windowFullscreen.dispose();
    _subtitleLift
      ..removeListener(_applySubtitleLift)
      ..dispose();
    _videoFit.dispose();
    super.dispose();
  }

  void _onEngineChanged() {
    if (!mounted) return;
    // A new native player (changed decoding preferences) brings its own
    // controller.
    _followController();
    _pictureInPicture?.follow();
    setState(() {});
  }

  void _followController() {
    final controller = widget.engine.videoController;
    if (identical(controller, _controller)) return;
    _controller = controller;
    _subtitleKey = GlobalKey<SubtitleViewState>();
    _subtitleBase = null;
  }

  /// Keeps the Flutter subtitles above the visible controls.
  void _applySubtitleLift() {
    final view = _subtitleKey.currentState;
    if (!mounted || view == null) return;
    final base = widget.engine.subtitleViewConfiguration.padding;
    _subtitleBase = base;
    view.setPadding(
      base.copyWith(bottom: base.bottom + _subtitleLift.value),
      duration: const Duration(milliseconds: 200),
    );
  }

  /// A phone that leaves the app without the small window pauses: nothing
  /// would show the video, and a torrent would stream on unseen. A desktop
  /// window, even minimised, plays on as other players do.
  void _onAppHidden() {
    if (widget.input != PlayerInputMode.touch) return;
    if (_pictureInPicture?.active.value ?? false) return;
    final engine = widget.engine;
    if (engine.hasPlayer) unawaited(engine.player.pause());
  }

  Future<void> _enterPictureInPicture() async {
    final windowsPictureInPicture =
        widget.pictureInPicture is WindowsPictureInPicture;
    try {
      final entered = await _pictureInPicture?.enter() ?? false;
      if (entered || !mounted) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              windowsPictureInPicture
                  ? AppLocalizations.of(context).playerPictureInPictureFailed
                  : AppLocalizations.of(context).playerPictureInPictureOff,
            ),
          ),
        );
    } catch (error) {
      debugPrint('Picture-in-picture enter failed: $error');
      if (mounted && windowsPictureInPicture) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).playerPictureInPictureFailed,
              ),
            ),
          );
      }
    }
  }

  void _onVideoFitChanged() {
    if (!mounted) return;
    setState(() {});
    final viewSize = _viewSize;
    if (viewSize != null) _liftSubtitles(_clearance, viewSize);
  }

  /// Moves the subtitles above [clearance] pixels of controls at the
  /// bottom of a [viewSize] box the video is fitted into.
  void _liftSubtitles(double clearance, Size viewSize) {
    _clearance = clearance;
    _viewSize = viewSize;
    _subtitleLift.value = clearance;
    final engine = widget.engine;
    if (!engine.hasPlayer) return;
    // mpv places its subtitles relative to the video, not the box.
    final state = engine.player.state;
    var videoHeight = viewSize.height;
    final width = state.width;
    final height = state.height;
    if (width != null && height != null && width > 0 && height > 0) {
      final fitted = viewSize.width * height / width;
      // A filled box crops the video's bottom, and the subtitles with it,
      // unless they rise past the edge.
      videoHeight = _videoFit.value == BoxFit.cover
          ? math.max(fitted, viewSize.height)
          : math.min(fitted, viewSize.height);
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

  /// The video zoomed to the fit chosen, and the subtitles Flutter draws
  /// over it, kept whole and in the box rather than zoomed with it.
  Widget _buildVideo(MediaKitPlayerEngine engine) {
    final subtitles = engine.subtitleViewConfiguration;
    final player = engine.hasPlayer ? engine.player : null;
    final libass = player?.platform?.configuration.libass ?? false;
    final drawsSubtitles = subtitles.visible && !libass;
    if (drawsSubtitles && subtitles.padding != _subtitleBase) {
      // The view mounts, or takes new settings, in this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _applySubtitleLift());
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _FittedVideo(
          fit: _videoFit.value,
          videoSize: switch (player?.state) {
            PlayerState(:final width?, :final height?)
                when width > 0 && height > 0 =>
              Size(width.toDouble(), height.toDouble()),
            _ => null,
          },
          child: widget.videoSurfaceBuilder(controller: _controller),
        ),
        if (drawsSubtitles)
          SubtitleView(
            key: _subtitleKey,
            controller: _controller,
            configuration: subtitles,
          ),
      ],
    );
  }

  /// The video fills the box; the controls lie over it.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = widget.engine;
    final Widget video;
    final Widget? failure;
    if (engine.startupState.phase == PlayerEnginePhase.failed) {
      video = const SizedBox.expand();
      failure = _buildFailure(context, l10n);
    } else {
      video = _buildVideo(engine);
      failure = null;
    }
    final pictureInPicture = _pictureInPicture;
    if (pictureInPicture == null) {
      return _buildControls(context, video, failure, l10n);
    }
    final windowsPictureInPicture = switch (widget.pictureInPicture) {
      WindowsPictureInPicture window => window,
      _ => null,
    };
    return ValueListenableBuilder<bool>(
      valueListenable: pictureInPicture.active,
      builder: (context, active, _) => _buildControls(
        context,
        video,
        failure,
        l10n,
        pictureInPicture: active,
        onPictureInPicture: pictureInPicture.supported
            ? () => unawaited(_enterPictureInPicture())
            : null,
        windowsPictureInPicture: active ? windowsPictureInPicture : null,
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    Widget video,
    Widget? failure,
    AppLocalizations l10n, {
    bool pictureInPicture = false,
    VoidCallback? onPictureInPicture,
    WindowsPictureInPicture? windowsPictureInPicture,
  }) {
    final engine = widget.engine;
    return PlayerImmersiveControls(
      engine: engine,
      chrome: widget.chrome,
      input: widget.input,
      next: widget.next,
      video: video,
      // The retry panel can overflow the Windows minimum window. Keep its
      // error message visible and leave retry on the restored player screen.
      failure: windowsPictureInPicture != null && failure != null
          ? _buildFailure(context, l10n, compact: true)
          : failure,
      startupLabel: _playerStartupLabel(l10n, engine),
      statsPanel: _buildStatsPanel(),
      fullscreen: _windowFullscreen,
      onToggleFullscreen: _toggleWindowFullscreen,
      onSubtitleClearance: _liftSubtitles,
      videoFit: _videoFit,
      brightness: widget.brightness,
      pictureInPicture: pictureInPicture,
      onPictureInPicture: onPictureInPicture,
      windowsPictureInPicture: windowsPictureInPicture != null,
      onRestorePictureInPicture: windowsPictureInPicture == null
          ? null
          : () => _runWindowsPictureInPictureCommand(
              'restore',
              windowsPictureInPicture.restore,
            ),
      onDismissPictureInPicture: windowsPictureInPicture == null
          ? null
          : () => _runWindowsPictureInPictureCommand(
              'dismiss',
              windowsPictureInPicture.dismiss,
            ),
      onDragPictureInPicture: windowsPictureInPicture == null
          ? null
          : () => _runWindowsPictureInPictureCommand(
              'drag',
              windowsPictureInPicture.startDragging,
            ),
      onShowTracks: (anchor) => _showTrackSelectorSheet(anchor: anchor),
      onShowSettings: (anchor) => _showSettingsSheet(anchor: anchor),
    );
  }

  void _runWindowsPictureInPictureCommand(
    String command,
    Future<void> Function() run,
  ) {
    unawaited(() async {
      try {
        await run();
      } catch (error) {
        debugPrint('Windows picture-in-picture $command failed: $error');
      }
    }());
  }

  Widget _buildFailure(
    BuildContext context,
    AppLocalizations l10n, {
    bool compact = false,
  }) {
    final engine = widget.engine;
    final errorMessage =
        engine.startupState.failure == PlayerEngineFailure.firstFrameTimeout
        ? l10n.playerUnableToPrepareFirstFrame
        : l10n.playerUnableToStart;
    if (compact) {
      return Positioned(
        top: 52,
        left: 12,
        right: 12,
        bottom: 8,
        child: Center(
          child: Text(
            errorMessage,
            key: const Key('player_picture_in_picture_failure'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white),
          ),
        ),
      );
    }
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

  Widget _buildStatsPanel() {
    final engine = widget.engine;
    return Flexible(
      fit: FlexFit.loose,
      child: Align(
        alignment: Alignment.centerLeft,
        // As tall as the stats, not the row: the top bar has no fixed
        // height.
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _PlayerControlsStatsPanel(
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

  Future<void> _showSettingsSheet({BuildContext? anchor}) =>
      showPlayerSubtitleSettingsSheet(
        context,
        anchor: anchor,
        speed: PlayerSpeedSetting(
          rate: widget.engine.playbackRate,
          onSelected: widget.engine.setPlaybackRate,
        ),
        quality: PlayerQualitySetting(
          choice: widget.engine.quality,
          onSelected: (height) =>
              unawaited(widget.engine.chooseQuality(height)),
        ),
      );

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
/// does.
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

Widget _defaultVideoSurfaceBuilder({required VideoController controller}) {
  return Video(
    key: const Key('player_video_surface'),
    controller: controller,
    controls: NoVideoControls,
    // The viewport draws them, unzoomed.
    subtitleViewConfiguration: const SubtitleViewConfiguration(visible: false),
  );
}
