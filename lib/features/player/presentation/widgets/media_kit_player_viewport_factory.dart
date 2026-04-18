import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/widgets/player_audio_fallback_resolver.dart';
import 'package:iris/features/player/presentation/widgets/player_playback_stats_indicator.dart';
import 'package:iris/features/player/presentation/widgets/player_subtitle_preferences_mapper.dart';
import 'package:iris/features/player/presentation/widgets/player_subtitle_settings_sheet.dart';
import 'package:iris/features/player/presentation/widgets/player_track_selector_sheet.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

typedef MediaKitPlayerBuilder =
    Player Function(PlayerConfiguration configuration);
typedef MediaKitVideoControllerBuilder =
    VideoController Function(Player player);
typedef MediaKitFirstFrameAwaiter =
    Future<void> Function(VideoController controller);
typedef MediaKitVideoSurfaceBuilder =
    Widget Function({
      required VideoController controller,
      required SubtitleViewConfiguration subtitleViewConfiguration,
      required MaterialVideoControlsThemeData normalTheme,
      required MaterialVideoControlsThemeData fullscreenTheme,
    });

class MediaKitPlayerViewportFactory implements PlayerViewportFactory {
  MediaKitPlayerViewportFactory({
    required PlayerRepository repository,
    MediaKitPlayerBuilder? playerBuilder,
    MediaKitVideoControllerBuilder? videoControllerBuilder,
    MediaKitFirstFrameAwaiter? firstFrameAwaiter,
    MediaKitVideoSurfaceBuilder? videoSurfaceBuilder,
    Duration mediaKitStartupTimeout = const Duration(seconds: 45),
  }) : _repository = repository,
       _playerBuilder = playerBuilder ?? _defaultPlayerBuilder,
       _videoControllerBuilder =
           videoControllerBuilder ?? _defaultVideoControllerBuilder,
       _firstFrameAwaiter = firstFrameAwaiter ?? _defaultFirstFrameAwaiter,
       _videoSurfaceBuilder =
           videoSurfaceBuilder ?? _defaultVideoSurfaceBuilder,
       _mediaKitStartupTimeout = mediaKitStartupTimeout;

  final PlayerRepository _repository;
  final MediaKitPlayerBuilder _playerBuilder;
  final MediaKitVideoControllerBuilder _videoControllerBuilder;
  final MediaKitFirstFrameAwaiter _firstFrameAwaiter;
  final MediaKitVideoSurfaceBuilder _videoSurfaceBuilder;
  final Duration _mediaKitStartupTimeout;

  @override
  Widget build({
    required AnimePlayerSource source,
    required PlayerSession session,
  }) {
    return _MediaKitPlayerViewport(
      source: source,
      session: session,
      repository: _repository,
      playerBuilder: _playerBuilder,
      videoControllerBuilder: _videoControllerBuilder,
      firstFrameAwaiter: _firstFrameAwaiter,
      videoSurfaceBuilder: _videoSurfaceBuilder,
      mediaKitStartupTimeout: _mediaKitStartupTimeout,
    );
  }
}

class _MediaKitPlayerViewport extends StatefulWidget {
  const _MediaKitPlayerViewport({
    required this.source,
    required this.session,
    required this.repository,
    required this.playerBuilder,
    required this.videoControllerBuilder,
    required this.firstFrameAwaiter,
    required this.videoSurfaceBuilder,
    required this.mediaKitStartupTimeout,
  });

  final AnimePlayerSource source;
  final PlayerSession session;
  final PlayerRepository repository;
  final MediaKitPlayerBuilder playerBuilder;
  final MediaKitVideoControllerBuilder videoControllerBuilder;
  final MediaKitFirstFrameAwaiter firstFrameAwaiter;
  final MediaKitVideoSurfaceBuilder videoSurfaceBuilder;
  final Duration mediaKitStartupTimeout;

  @override
  State<_MediaKitPlayerViewport> createState() =>
      _MediaKitPlayerViewportState();
}

class _MediaKitPlayerViewportState extends State<_MediaKitPlayerViewport> {
  late SubtitlePreferences _subtitlePreferences;
  late Player _player;
  late VideoController _videoController;

  StreamSubscription<bool>? _bufferingSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Track>? _trackSubscription;
  StreamSubscription<Tracks>? _tracksSubscription;
  StreamSubscription<PlayerPlaybackStats>? _playbackStatsSubscription;
  StreamSubscription<SubtitlePreferences>? _subtitlePreferencesSubscription;

  bool _recoveringAudioTrack = false;
  bool _reconfiguringPlayback = false;
  bool _isPlayerBuffering = false;
  Track _selectedTrack = const Track();
  final ValueNotifier<PlayerPlaybackStats?> _playbackStatsNotifier =
      ValueNotifier<PlayerPlaybackStats?>(null);
  _MediaKitViewportStartupState _startupState =
      const _MediaKitViewportStartupState.openingSource();
  Timer? _startupTimeoutTimer;
  int _startupGeneration = 0;

  @override
  void initState() {
    super.initState();
    _subtitlePreferences = context.read<PlayerSubtitlePreferencesCubit>().state;
    developer.log(
      'Creating media_kit viewport. sessionId=${widget.session.sessionId} source=${widget.source.sourceTitle}',
      name: 'iris.player.media',
    );
    _createPlayer();
    _subtitlePreferencesSubscription = context
        .read<PlayerSubtitlePreferencesCubit>()
        .stream
        .listen((preferences) {
          unawaited(_handleSubtitlePreferencesChanged(preferences));
        });
    _playbackStatsSubscription = widget.repository
        .watchPlaybackStats(sessionId: widget.session.sessionId)
        .listen((stats) {
          _playbackStatsNotifier.value = stats;
        });
    _openPlayback();
  }

  Future<void> _handleSubtitlePreferencesChanged(
    SubtitlePreferences next,
  ) async {
    final previous = _subtitlePreferences;
    _subtitlePreferences = next;

    if (requiresPlaybackRecreation(previous, next)) {
      await _recreatePlayer();
      return;
    }

    if (mounted) {
      setState(() {});
    }

    await _applyNativePlayerProperties();
  }

  void _createPlayer() {
    final configuration = buildPlayerRenderingConfiguration(
      _subtitlePreferences,
    );
    _player = widget.playerBuilder(configuration.playerConfiguration);
    _videoController = widget.videoControllerBuilder(_player);
    _selectedTrack = _player.state.track;
    _isPlayerBuffering = _player.state.buffering;
    _attachDebugListeners();
  }

  Future<void> _openPlayback() async {
    final startupGeneration = ++_startupGeneration;
    _cancelStartupTimeout();
    if (mounted) {
      setState(() {
        _startupState = const _MediaKitViewportStartupState.openingSource();
      });
    } else {
      _startupState = const _MediaKitViewportStartupState.openingSource();
    }

    developer.log(
      'Opening media source in media_kit. url=${widget.session.streamUrl}',
      name: 'iris.player.media',
    );
    try {
      await _applyNativePlayerProperties();
      await _player.open(Media(widget.session.streamUrl));

      if (!mounted || startupGeneration != _startupGeneration) {
        return;
      }

      developer.log(
        'media_kit opened the stream successfully. Waiting for first frame or timeline metadata.',
        name: 'iris.player.media',
      );
      setState(() {});
      _transitionToWaitingForFirstFrame(startupGeneration);
    } catch (error, stackTrace) {
      developer.log(
        'media_kit failed to open the stream.',
        name: 'iris.player.media',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted || startupGeneration != _startupGeneration) {
        return;
      }

      _failViewport(_ViewportFailureType.generic);
    }
  }

  Future<void> _applyNativePlayerProperties() async {
    final platform = _player.platform;
    if (platform == null) {
      return;
    }

    final properties = buildPlayerRenderingConfiguration(
      _subtitlePreferences,
    ).mpvProperties;

    try {
      for (final entry in properties.entries) {
        await (platform as dynamic).setProperty(entry.key, entry.value);
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to apply native player properties.',
        name: 'iris.player.media',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _recreatePlayer() async {
    if (_reconfiguringPlayback) {
      return;
    }

    developer.log(
      'Recreating media_kit player because subtitle renderer changed. sessionId=${widget.session.sessionId} libass=${_subtitlePreferences.libassEnabled}',
      name: 'iris.player.media',
    );

    setState(() {
      _reconfiguringPlayback = true;
      _startupState = const _MediaKitViewportStartupState.openingSource();
    });

    await _disposePlayerResources();
    _createPlayer();

    if (mounted) {
      setState(() {});
    }

    await _openPlayback();

    if (mounted) {
      setState(() {
        _reconfiguringPlayback = false;
      });
    } else {
      _reconfiguringPlayback = false;
    }
  }

  void _attachDebugListeners() {
    _bufferingSubscription = _player.stream.buffering.listen((buffering) {
      developer.log(
        'media_kit buffering changed: $buffering',
        name: 'iris.player.media',
      );
      if (_isPlayerBuffering != buffering) {
        if (mounted) {
          setState(() {
            _isPlayerBuffering = buffering;
          });
        } else {
          _isPlayerBuffering = buffering;
        }
      }
      unawaited(_logCacheBufferingState('buffering changed'));
    });
    _playingSubscription = _player.stream.playing.listen((playing) {
      developer.log(
        'media_kit playing changed: $playing',
        name: 'iris.player.media',
      );
    });
    _completedSubscription = _player.stream.completed.listen((completed) {
      developer.log(
        'media_kit completed changed: $completed',
        name: 'iris.player.media',
      );
    });
    _durationSubscription = _player.stream.duration.listen((duration) {
      final hasDuration = duration > Duration.zero;
      if (_startupState.hasDuration == hasDuration) {
        return;
      }

      developer.log(
        'media_kit duration metadata changed. duration=$duration hasDuration=$hasDuration',
        name: 'iris.player.media',
      );
      _updateStartupState(hasDuration: hasDuration);
      _markViewportReadyIfPrepared();
    });
    _trackSubscription = _player.stream.track.listen((track) {
      if (_selectedTrack == track) {
        return;
      }

      developer.log(
        'media_kit selected tracks changed. video=${track.video.codec} audio=${track.audio.codec} subtitle=${track.subtitle.codec}',
        name: 'iris.player.media',
      );
      if (mounted) {
        setState(() {
          _selectedTrack = track;
        });
      } else {
        _selectedTrack = track;
      }
    });
    _tracksSubscription = _player.stream.tracks.listen((tracks) {
      final hasVideoTrack = _hasRealVideoTrack(tracks);
      if (_startupState.hasVideoTrack == hasVideoTrack) {
        return;
      }

      developer.log(
        'media_kit available video tracks changed. count=${tracks.video.length} hasVideoTrack=$hasVideoTrack',
        name: 'iris.player.media',
      );
      _updateStartupState(hasVideoTrack: hasVideoTrack);
      _markViewportReadyIfPrepared();
    });
    _errorSubscription = _player.stream.error.listen((error) {
      developer.log(
        'media_kit emitted player error: $error',
        name: 'iris.player.media',
      );
      final fallback = resolveAudioFallbackTrack(
        errorMessage: error,
        audioTracks: _player.state.tracks.audio,
        selectedAudioTrack: _player.state.track.audio,
      );
      if (fallback != null && !_recoveringAudioTrack) {
        developer.log(
          'Attempting audio fallback after decoder error. selected=${_player.state.track.audio.codec} fallback=${fallback.codec} fallbackId=${fallback.id}',
          name: 'iris.player.media',
        );
        unawaited(_recoverFromUnsupportedAudio(fallback));
        return;
      }
      if (!mounted) {
        return;
      }

      _failViewport(_ViewportFailureType.generic);
    });
  }

  Future<void> _recoverFromUnsupportedAudio(AudioTrack fallbackTrack) async {
    _recoveringAudioTrack = true;
    try {
      await _player.setAudioTrack(fallbackTrack);
      await _player.play();
      developer.log(
        'Audio fallback applied successfully. codec=${fallbackTrack.codec} trackId=${fallbackTrack.id}',
        name: 'iris.player.media',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Audio fallback failed.',
        name: 'iris.player.media',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      _failViewport(_ViewportFailureType.generic);
    } finally {
      _recoveringAudioTrack = false;
    }
  }

  void _transitionToWaitingForFirstFrame(int startupGeneration) {
    if (!mounted || startupGeneration != _startupGeneration) {
      return;
    }

    _updateStartupState(phase: _MediaKitViewportPhase.waitingForFirstFrame);
    _startupTimeoutTimer = Timer(widget.mediaKitStartupTimeout, () {
      unawaited(_handleViewportStartupTimeout(startupGeneration));
    });
    unawaited(_awaitFirstFrame(startupGeneration));
    _markViewportReadyIfPrepared();
  }

  Future<void> _awaitFirstFrame(int startupGeneration) async {
    try {
      await widget.firstFrameAwaiter(_videoController);
      if (!mounted || startupGeneration != _startupGeneration) {
        return;
      }

      developer.log(
        'media_kit rendered the first frame successfully.',
        name: 'iris.player.media',
      );
      _updateStartupState(firstFrameRendered: true);
      _markViewportReadyIfPrepared();
    } catch (error, stackTrace) {
      if (!mounted || startupGeneration != _startupGeneration) {
        return;
      }

      developer.log(
        'media_kit failed while waiting for the first frame.',
        name: 'iris.player.media',
        error: error,
        stackTrace: stackTrace,
      );
      _failViewport(_ViewportFailureType.generic);
    }
  }

  Future<void> _handleViewportStartupTimeout(int startupGeneration) async {
    if (!mounted ||
        startupGeneration != _startupGeneration ||
        _startupState.phase != _MediaKitViewportPhase.waitingForFirstFrame) {
      return;
    }

    await _logCacheBufferingState('first frame timeout');
    developer.log(
      'media_kit startup timed out before the first frame was ready. hasDuration=${_startupState.hasDuration} hasVideoTrack=${_startupState.hasVideoTrack} firstFrameRendered=${_startupState.firstFrameRendered}',
      name: 'iris.player.media',
    );
    _failViewport(_ViewportFailureType.firstFrameTimeout);
  }

  void _markViewportReadyIfPrepared() {
    if (_startupState.phase != _MediaKitViewportPhase.waitingForFirstFrame) {
      return;
    }

    final hasFallbackReadiness =
        _startupState.hasDuration && _startupState.hasVideoTrack;
    if (!_startupState.firstFrameRendered && !hasFallbackReadiness) {
      return;
    }

    developer.log(
      'media_kit viewport is ready. firstFrameRendered=${_startupState.firstFrameRendered} hasDuration=${_startupState.hasDuration} hasVideoTrack=${_startupState.hasVideoTrack}',
      name: 'iris.player.media',
    );
    _cancelStartupTimeout();
    _updateStartupState(phase: _MediaKitViewportPhase.ready);
  }

  void _failViewport(_ViewportFailureType failureType) {
    _cancelStartupTimeout();
    if (!mounted) {
      _startupState = _startupState.copyWith(
        phase: _MediaKitViewportPhase.failed,
        failureType: failureType,
      );
      return;
    }

    setState(() {
      _startupState = _startupState.copyWith(
        phase: _MediaKitViewportPhase.failed,
        failureType: failureType,
      );
    });
  }

  void _updateStartupState({
    _MediaKitViewportPhase? phase,
    bool? hasDuration,
    bool? hasVideoTrack,
    bool? firstFrameRendered,
    _ViewportFailureType? failureType,
  }) {
    final nextState = _startupState.copyWith(
      phase: phase,
      hasDuration: hasDuration,
      hasVideoTrack: hasVideoTrack,
      firstFrameRendered: firstFrameRendered,
      failureType: failureType,
    );
    if (nextState == _startupState) {
      return;
    }

    if (!mounted) {
      _startupState = nextState;
      return;
    }

    setState(() {
      _startupState = nextState;
    });
  }

  void _cancelStartupTimeout() {
    _startupTimeoutTimer?.cancel();
    _startupTimeoutTimer = null;
  }

  Future<void> _logCacheBufferingState(String reason) async {
    final platform = _player.platform;
    if (platform == null) {
      return;
    }

    try {
      final cacheBufferingState = await (platform as dynamic).getProperty(
        'cache-buffering-state',
        waitForInitialization: false,
      );
      developer.log(
        'media_kit cache buffering state. reason=$reason value=$cacheBufferingState',
        name: 'iris.player.media',
      );
    } catch (_) {}
  }

  Future<void> _showTrackSelectorSheet() async {
    final tracks = _player.state.tracks;
    final selectedTrack = _player.state.track;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return PlayerTrackSelectorSheet(
          audioTracks: tracks.audio,
          selectedAudioTrack: selectedTrack.audio,
          subtitleTracks: tracks.subtitle,
          selectedSubtitleTrack: selectedTrack.subtitle,
          onAudioTrackSelected: (track) async {
            await _player.setAudioTrack(track);
            if (!sheetContext.mounted) {
              return;
            }
            Navigator.of(sheetContext).pop();
          },
          onSubtitleTrackSelected: (track) async {
            await _player.setSubtitleTrack(track);
            if (!sheetContext.mounted) {
              return;
            }
            Navigator.of(sheetContext).pop();
          },
          onSubtitleAppearancePressed: () {
            Navigator.of(sheetContext).pop();
            unawaited(_showSubtitleSettingsSheet());
          },
        );
      },
    );
  }

  Future<void> _showSubtitleSettingsSheet() async {
    await showPlayerSubtitleSettingsSheet(context);
  }

  Future<void> _disposePlayerResources() async {
    _cancelStartupTimeout();
    await _bufferingSubscription?.cancel();
    await _playingSubscription?.cancel();
    await _completedSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _trackSubscription?.cancel();
    await _tracksSubscription?.cancel();
    await _player.dispose();
  }

  @override
  void dispose() {
    developer.log(
      'Disposing media_kit viewport. sessionId=${widget.session.sessionId}',
      name: 'iris.player.media',
    );
    unawaited(_subtitlePreferencesSubscription?.cancel());
    unawaited(_playbackStatsSubscription?.cancel());
    unawaited(_disposePlayerResources());
    _playbackStatsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final renderingConfiguration = buildPlayerRenderingConfiguration(
      _subtitlePreferences,
    );

    if (_startupState.phase == _MediaKitViewportPhase.failed) {
      final errorMessage =
          _startupState.failureType == _ViewportFailureType.firstFrameTimeout
          ? l10n.playerUnableToPrepareFirstFrame
          : l10n.playerUnableToStart;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              Text(errorMessage, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  _openPlayback();
                },
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.source.fileName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.source.sourceTitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.videoSurfaceBuilder(
                    controller: _videoController,
                    subtitleViewConfiguration:
                        renderingConfiguration.subtitleViewConfiguration,
                    normalTheme: _buildControlsTheme(l10n),
                    fullscreenTheme: _buildControlsTheme(l10n),
                  ),
                  if (_reconfiguringPlayback ||
                      _startupState.phase != _MediaKitViewportPhase.ready)
                    ColoredBox(
                      key: const Key('player_viewport_loading_overlay'),
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              _startupState.phase ==
                                      _MediaKitViewportPhase.openingSource
                                  ? l10n.playerPreparing
                                  : l10n.playerBuffering,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  MaterialVideoControlsThemeData _buildControlsTheme(AppLocalizations l10n) {
    return MaterialVideoControlsThemeData(
      primaryButtonBar: const [Spacer(), MaterialPlayOrPauseButton(), Spacer()],
      topButtonBar: [
        Flexible(
          fit: FlexFit.loose,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: PlayerPlaybackStatsListenable(
                listenable: _playbackStatsNotifier,
                videoCodec: _selectedTrack.video.codec,
                audioCodec: _selectedTrack.audio.codec,
                isBuffering:
                    _startupState.phase == _MediaKitViewportPhase.ready &&
                    _isPlayerBuffering,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        MaterialCustomButton(
          icon: const Icon(Icons.tune),
          onPressed: _showTrackSelectorSheet,
        ),
      ],
      bottomButtonBar: const [
        MaterialPositionIndicator(),
        Spacer(),
        MaterialFullscreenButton(),
      ],
      volumeGesture: true,
      brightnessGesture: true,
      seekGesture: true,
      seekOnDoubleTap: true,
      bufferingIndicatorBuilder: (context) =>
          _BufferingIndicator(label: l10n.playerBuffering),
    );
  }
}

enum _MediaKitViewportPhase {
  openingSource,
  waitingForFirstFrame,
  ready,
  failed,
}

enum _ViewportFailureType { generic, firstFrameTimeout }

class _MediaKitViewportStartupState {
  const _MediaKitViewportStartupState({
    required this.phase,
    required this.hasDuration,
    required this.hasVideoTrack,
    required this.firstFrameRendered,
    required this.failureType,
  });

  const _MediaKitViewportStartupState.openingSource()
    : this(
        phase: _MediaKitViewportPhase.openingSource,
        hasDuration: false,
        hasVideoTrack: false,
        firstFrameRendered: false,
        failureType: _ViewportFailureType.generic,
      );

  final _MediaKitViewportPhase phase;
  final bool hasDuration;
  final bool hasVideoTrack;
  final bool firstFrameRendered;
  final _ViewportFailureType failureType;

  _MediaKitViewportStartupState copyWith({
    _MediaKitViewportPhase? phase,
    bool? hasDuration,
    bool? hasVideoTrack,
    bool? firstFrameRendered,
    _ViewportFailureType? failureType,
  }) {
    return _MediaKitViewportStartupState(
      phase: phase ?? this.phase,
      hasDuration: hasDuration ?? this.hasDuration,
      hasVideoTrack: hasVideoTrack ?? this.hasVideoTrack,
      firstFrameRendered: firstFrameRendered ?? this.firstFrameRendered,
      failureType: failureType ?? this.failureType,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _MediaKitViewportStartupState &&
        other.phase == phase &&
        other.hasDuration == hasDuration &&
        other.hasVideoTrack == hasVideoTrack &&
        other.firstFrameRendered == firstFrameRendered &&
        other.failureType == failureType;
  }

  @override
  int get hashCode => Object.hash(
    phase,
    hasDuration,
    hasVideoTrack,
    firstFrameRendered,
    failureType,
  );
}

bool _hasRealVideoTrack(Tracks tracks) {
  return tracks.video.any((track) => track.id != 'auto' && track.id != 'no');
}

class _BufferingIndicator extends StatelessWidget {
  const _BufferingIndicator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}

Player _defaultPlayerBuilder(PlayerConfiguration configuration) {
  return Player(configuration: configuration);
}

VideoController _defaultVideoControllerBuilder(Player player) {
  return VideoController(player);
}

Future<void> _defaultFirstFrameAwaiter(VideoController controller) {
  return controller.waitUntilFirstFrameRendered;
}

Widget _defaultVideoSurfaceBuilder({
  required VideoController controller,
  required SubtitleViewConfiguration subtitleViewConfiguration,
  required MaterialVideoControlsThemeData normalTheme,
  required MaterialVideoControlsThemeData fullscreenTheme,
}) {
  return MaterialVideoControlsTheme(
    normal: normalTheme,
    fullscreen: fullscreenTheme,
    child: Video(
      key: const Key('player_video_surface'),
      controller: controller,
      controls: MaterialVideoControls,
      subtitleViewConfiguration: subtitleViewConfiguration,
    ),
  );
}
