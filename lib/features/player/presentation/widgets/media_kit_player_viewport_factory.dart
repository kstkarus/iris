import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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

export 'package:iris/features/player/presentation/playback/media_kit_player_engine.dart'
    show
        MediaKitFirstFrameAwaiter,
        MediaKitPlayerBuilder,
        MediaKitVideoControllerBuilder;

part 'media_kit/subtitle_lift.dart';
part 'media_kit/player_controls_stats_panel.dart';

/// Builds the video itself; [controls] go in media_kit's controls slot.
typedef MediaKitVideoSurfaceBuilder =
    Widget Function({
      required VideoController controller,
      required SubtitleViewConfiguration subtitleViewConfiguration,
      required VideoControlsBuilder controls,
    });

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
  });

  final MediaKitPlayerEngine engine;
  final PlayerNextFile? next;
  final PlayerChrome chrome;
  final PlayerInputMode input;
  final MediaKitVideoSurfaceBuilder videoSurfaceBuilder;
  final NativeFullscreenToggle enterNativeFullscreen;
  final NativeFullscreenToggle exitNativeFullscreen;

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

  @override
  void initState() {
    super.initState();
    widget.engine.addListener(_onEngineChanged);
  }

  @override
  void didUpdateWidget(covariant _MediaKitPlayerViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engine != widget.engine) {
      oldWidget.engine.removeListener(_onEngineChanged);
      widget.engine.addListener(_onEngineChanged);
      _controller = widget.engine.videoController;
    }
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngineChanged);
    if (_windowFullscreen.value) unawaited(widget.exitNativeFullscreen());
    _windowFullscreen.dispose();
    _subtitleLift.dispose();
    super.dispose();
  }

  void _onEngineChanged() {
    if (!mounted) return;
    // A new native player (changed decoding preferences) brings its own
    // controller.
    _controller = widget.engine.videoController;
    setState(() {});
  }

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

  /// The video fills the box; the controls lie over it.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final engine = widget.engine;
    final Widget video;
    final Widget? failure;
    if (engine.startupState.phase == PlayerEnginePhase.failed) {
      video = const SizedBox.expand();
      failure = _buildFailure(l10n);
    } else {
      video = widget.videoSurfaceBuilder(
        controller: _controller,
        subtitleViewConfiguration: engine.subtitleViewConfiguration,
        controls: _subtitleLiftControls(_subtitleLift),
      );
      failure = null;
    }
    return PlayerImmersiveControls(
      engine: engine,
      chrome: widget.chrome,
      input: widget.input,
      next: widget.next,
      video: video,
      failure: failure,
      startupLabel: _playerStartupLabel(l10n, engine),
      statsPanel: _buildStatsPanel(),
      fullscreen: _windowFullscreen,
      onToggleFullscreen: _toggleWindowFullscreen,
      onSubtitleClearance: _liftSubtitles,
      onShowTracks: (anchor) => _showTrackSelectorSheet(anchor: anchor),
      onShowSettings: (anchor) => _showSettingsSheet(anchor: anchor),
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

Widget _defaultVideoSurfaceBuilder({
  required VideoController controller,
  required SubtitleViewConfiguration subtitleViewConfiguration,
  required VideoControlsBuilder controls,
}) {
  return Video(
    key: const Key('player_video_surface'),
    controller: controller,
    controls: controls,
    subtitleViewConfiguration: subtitleViewConfiguration,
  );
}
