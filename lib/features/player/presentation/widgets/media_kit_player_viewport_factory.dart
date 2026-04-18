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
    MediaKitVideoSurfaceBuilder? videoSurfaceBuilder,
  }) : _repository = repository,
       _playerBuilder = playerBuilder ?? _defaultPlayerBuilder,
       _videoControllerBuilder =
           videoControllerBuilder ?? _defaultVideoControllerBuilder,
       _videoSurfaceBuilder =
           videoSurfaceBuilder ?? _defaultVideoSurfaceBuilder;

  final PlayerRepository _repository;
  final MediaKitPlayerBuilder _playerBuilder;
  final MediaKitVideoControllerBuilder _videoControllerBuilder;
  final MediaKitVideoSurfaceBuilder _videoSurfaceBuilder;

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
      videoSurfaceBuilder: _videoSurfaceBuilder,
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
    required this.videoSurfaceBuilder,
  });

  final AnimePlayerSource source;
  final PlayerSession session;
  final PlayerRepository repository;
  final MediaKitPlayerBuilder playerBuilder;
  final MediaKitVideoControllerBuilder videoControllerBuilder;
  final MediaKitVideoSurfaceBuilder videoSurfaceBuilder;

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
  StreamSubscription<PlayerPlaybackStats>? _playbackStatsSubscription;
  StreamSubscription<SubtitlePreferences>? _subtitlePreferencesSubscription;

  bool _openFailed = false;
  bool _recoveringAudioTrack = false;
  bool _reconfiguringPlayback = false;
  PlayerPlaybackStats? _playbackStats;

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
          if (!mounted) {
            return;
          }
          setState(() {
            _playbackStats = stats;
          });
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

    if (next.libassEnabled) {
      await _applyNativeSubtitlePreferences();
    }
  }

  void _createPlayer() {
    final configuration = buildPlayerRenderingConfiguration(
      _subtitlePreferences,
    );
    _player = widget.playerBuilder(configuration.playerConfiguration);
    _videoController = widget.videoControllerBuilder(_player);
    _attachDebugListeners();
  }

  Future<void> _openPlayback() async {
    developer.log(
      'Opening media source in media_kit. url=${widget.session.streamUrl}',
      name: 'iris.player.media',
    );
    try {
      await _player.open(Media(widget.session.streamUrl));
      await _applyNativeSubtitlePreferences();

      if (!mounted) {
        return;
      }

      developer.log(
        'media_kit opened the stream successfully.',
        name: 'iris.player.media',
      );
      setState(() {});
    } catch (error, stackTrace) {
      developer.log(
        'media_kit failed to open the stream.',
        name: 'iris.player.media',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _openFailed = true;
      });
    }
  }

  Future<void> _applyNativeSubtitlePreferences() async {
    if (!_subtitlePreferences.libassEnabled) {
      return;
    }

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
        'Failed to apply native subtitle preferences.',
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
      _openFailed = false;
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

      setState(() {
        _openFailed = true;
      });
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
      setState(() {
        _openFailed = true;
      });
    } finally {
      _recoveringAudioTrack = false;
    }
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
    await _bufferingSubscription?.cancel();
    await _playingSubscription?.cancel();
    await _completedSubscription?.cancel();
    await _errorSubscription?.cancel();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final renderingConfiguration = buildPlayerRenderingConfiguration(
      _subtitlePreferences,
    );

    if (_openFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              Text(l10n.playerUnableToStart, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _openFailed = false;
                  });
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
                  if (_reconfiguringPlayback)
                    ColoredBox(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              l10n.playerPreparing,
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
        if (_playbackStats != null)
          PlayerPlaybackStatsIndicator(stats: _playbackStats!),
        const Spacer(),
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
