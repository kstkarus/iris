import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/entities/player_track_preferences.dart';
import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/domain/player_buffer_policy.dart';
import 'package:iris/features/player/domain/player_chapter_skip_segments.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/playback/player_engine.dart';
import 'package:iris/features/player/presentation/widgets/player_audio_fallback_resolver.dart';
import 'package:iris/features/player/presentation/widgets/player_buffer_health_tracker.dart';
import 'package:iris/features/player/presentation/widgets/player_playback_stats_indicator.dart';
import 'package:iris/features/player/presentation/widgets/player_subtitle_preferences_mapper.dart';
import 'package:iris/features/player/presentation/widgets/player_track_matcher.dart';

typedef MediaKitPlayerBuilder =
    Player Function(PlayerConfiguration configuration);
typedef MediaKitVideoControllerBuilder =
    VideoController Function(
      Player player,
      VideoControllerConfiguration configuration,
    );
typedef MediaKitFirstFrameAwaiter =
    Future<void> Function(VideoController controller);

enum PlayerEnginePhase { openingSource, waitingForFirstFrame, ready, failed }

enum PlayerEngineFailure { generic, firstFrameTimeout, transportStartupTimeout }

/// Startup progress of the currently opened file.
@immutable
class PlayerEngineStartupState {
  const PlayerEngineStartupState({
    required this.phase,
    required this.hasDuration,
    required this.hasVideoTrack,
    required this.firstFrameRendered,
    required this.failure,
  });

  const PlayerEngineStartupState.openingSource()
    : this(
        phase: PlayerEnginePhase.openingSource,
        hasDuration: false,
        hasVideoTrack: false,
        firstFrameRendered: false,
        failure: PlayerEngineFailure.generic,
      );

  final PlayerEnginePhase phase;
  final bool hasDuration;
  final bool hasVideoTrack;
  final bool firstFrameRendered;
  final PlayerEngineFailure failure;

  PlayerEngineStartupState copyWith({
    PlayerEnginePhase? phase,
    bool? hasDuration,
    bool? hasVideoTrack,
    bool? firstFrameRendered,
    PlayerEngineFailure? failure,
  }) {
    return PlayerEngineStartupState(
      phase: phase ?? this.phase,
      hasDuration: hasDuration ?? this.hasDuration,
      hasVideoTrack: hasVideoTrack ?? this.hasVideoTrack,
      firstFrameRendered: firstFrameRendered ?? this.firstFrameRendered,
      failure: failure ?? this.failure,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PlayerEngineStartupState &&
        other.phase == phase &&
        other.hasDuration == hasDuration &&
        other.hasVideoTrack == hasVideoTrack &&
        other.firstFrameRendered == firstFrameRendered &&
        other.failure == failure;
  }

  @override
  int get hashCode => Object.hash(
    phase,
    hasDuration,
    hasVideoTrack,
    firstFrameRendered,
    failure,
  );
}

/// [PlayerEngine] on media_kit (mpv). Owns the [Player] and its
/// [VideoController] for the whole player page; the viewport only renders
/// them. The player is recreated only when native rendering preferences
/// (libass, hardware decoding) change.
class MediaKitPlayerEngine extends ChangeNotifier implements PlayerEngine {
  MediaKitPlayerEngine({
    required PlayerRepository repository,
    required PlayerSubtitlePreferencesCubit subtitlePreferences,
    required PlayerDecodingPreferencesCubit decodingPreferences,
    MediaKitPlayerBuilder? playerBuilder,
    MediaKitVideoControllerBuilder? videoControllerBuilder,
    MediaKitFirstFrameAwaiter? firstFrameAwaiter,
    this.startupTimeout = const Duration(seconds: 45),
    this.stopTimeout = const Duration(seconds: 3),
  }) : _repository = repository,
       _playerBuilder = playerBuilder ?? _defaultPlayerBuilder,
       _videoControllerBuilder =
           videoControllerBuilder ?? _defaultVideoControllerBuilder,
       _firstFrameAwaiter = firstFrameAwaiter ?? _defaultFirstFrameAwaiter,
       _subtitlePreferences = subtitlePreferences.state,
       _decodingPreferences = decodingPreferences.state {
    _subtitlePreferencesSubscription = subtitlePreferences.stream.listen(
      (preferences) =>
          unawaited(_handleSubtitlePreferencesChanged(preferences)),
    );
    _decodingPreferencesSubscription = decodingPreferences.stream.listen(
      (preferences) =>
          unawaited(_handleDecodingPreferencesChanged(preferences)),
    );
  }

  final PlayerRepository _repository;
  final MediaKitPlayerBuilder _playerBuilder;
  final MediaKitVideoControllerBuilder _videoControllerBuilder;
  final MediaKitFirstFrameAwaiter _firstFrameAwaiter;

  /// How long the first frame may take before startup fails.
  final Duration startupTimeout;

  /// How long [stop] waits for mpv to close the stream before it disposes
  /// the player instead.
  final Duration stopTimeout;

  final _events = StreamController<PlayerEngineEvent>.broadcast();

  SubtitlePreferences _subtitlePreferences;
  PlayerDecodingPreferences _decodingPreferences;
  Player? _player;
  VideoController? _videoController;

  PlayerSession? _session;
  Duration? _startPosition;
  PlayerTrackPreferences? _preferredTracks;
  bool _preferredTracksApplied = false;

  /// Last position seen after startup; reopening (decoder change) resumes
  /// from here.
  Duration? _lastKnownPosition;

  /// A seek asked for before the file could take one, done once it can.
  Duration? _pendingSeek;

  /// Whether [PlayerEnginePlaybackStarted] went out for the open file.
  bool _startAnnounced = false;

  final List<StreamSubscription<Object?>> _playerSubscriptions = [];
  StreamSubscription<SubtitlePreferences>? _subtitlePreferencesSubscription;
  StreamSubscription<PlayerDecodingPreferences>?
  _decodingPreferencesSubscription;
  StreamSubscription<PlayerPlaybackStats>? _playbackStatsSubscription;
  String? _statsSessionId;

  /// Since the current file started opening, for the startup log.
  final _startupClock = Stopwatch();

  bool _recoveringAudioTrack = false;

  /// Share of the video's height kept clear for on-screen controls.
  double _subtitleLift = 0;
  bool _reconfiguring = false;
  bool _recreateQueued = false;
  bool _closed = false;
  final PlayerRebufferCycleTracker _rebufferCycleTracker =
      PlayerRebufferCycleTracker();

  PlayerEngineStartupState _startupState =
      const PlayerEngineStartupState.openingSource();
  Timer? _startupTimeoutTimer;
  Timer? _startupNetworkWatchdogTimer;
  Duration? _startupNetworkMonitoringElapsed;
  Duration? _lastStartupNetworkActivityAt;
  int _startupGeneration = 0;

  final playbackStats = ValueNotifier<PlayerPlaybackStats?>(null);
  final phase = ValueNotifier<PlayerEnginePhase>(
    PlayerEnginePhase.openingSource,
  );
  final selectedTrack = ValueNotifier<Track>(const Track());
  final buffering = ValueNotifier<bool>(false);
  final bufferMargin = ValueNotifier<PlayerBufferMarginState>(
    PlayerBufferMarginState.insufficient,
  );
  final diagnostics = ValueNotifier<PlayerPlaybackDiagnostics?>(null);

  /// The opened file played to its end.
  final completed = ValueNotifier<bool>(false);

  /// Playback reached the ending, or, when its start is unknown, the point
  /// where the file counts as watched.
  final finishing = ValueNotifier<bool>(false);

  /// The opening or recap playing now, when its end is known.
  final skipSegment = ValueNotifier<PlayerSkipSegment?>(null);

  /// The opening is unknown and the file has just started: a fixed jump of
  /// [skipForwardStep] is offered instead.
  final skipForwardOffered = ValueNotifier<bool>(false);

  /// A TV opening runs about 90 s; a little less never skips story.
  static const skipForwardStep = Duration(seconds: 85);

  /// Openings come within the first minutes, after a cold open at most.
  static const _skipForwardWindow = Duration(minutes: 5);

  List<PlayerSkipSegment> _chapterSegments = const [];
  List<PlayerSkipSegment> _lookedUpSegments = const [];

  List<PlayerSkipSegment> get _skipSegments =>
      _chapterSegments.isNotEmpty ? _chapterSegments : _lookedUpSegments;

  @override
  Stream<PlayerEngineEvent> get events => _events.stream;

  /// Created by the first [open]; replaced only when rendering preferences
  /// require a new native player.
  Player get player => _player!;
  VideoController get videoController => _videoController!;
  bool get hasPlayer => _player != null;

  PlayerEngineStartupState get startupState => _startupState;

  /// A new native player is being created for changed preferences.
  bool get reconfiguring => _reconfiguring;

  SubtitleViewConfiguration get subtitleViewConfiguration =>
      buildPlayerRenderingConfiguration(
        _subtitlePreferences,
        _decodingPreferences,
      ).subtitleViewConfiguration;

  /// Where to open the file: the current position after a player rebuild,
  /// otherwise the resume position.
  Duration? get _openPosition {
    final position = _lastKnownPosition ?? _startPosition;
    if (position == null || position <= Duration.zero) return null;
    return position;
  }

  @override
  Future<void> open(
    PlayerSession session, {
    Duration? startPosition,
    PlayerTrackPreferences? preferredTracks,
  }) {
    if (_closed) return Future<void>.value();
    _session = session;
    _startPosition = startPosition;
    _preferredTracks = preferredTracks;
    _preferredTracksApplied = false;
    _lastKnownPosition = null;
    _pendingSeek = null;
    _startAnnounced = false;
    completed.value = false;
    _resetPositionOffers();
    _watchPlaybackStats(session.sessionId);
    // Synchronous on purpose: the viewport can render the controller as soon
    // as this returns.
    if (_player == null) _createPlayer();
    return _openPlayback();
  }

  /// Opens the current file again after a startup failure.
  Future<void> retry() => _openPlayback();

  @override
  Future<void> seek(Duration position) async {
    _lastKnownPosition = position;
    final player = _player;
    if (player == null || _closed) return;
    // Until the file is loaded mpv drops seeks and then goes to the
    // position the file was opened at; keep this one until it can be done.
    if (!_canSeek) {
      _pendingSeek = position;
      return;
    }
    await player.seek(position);
  }

  bool get _canSeek => _startupState.hasDuration || _isReady;

  void _applyPendingSeek() {
    final position = _pendingSeek;
    final player = _player;
    if (position == null || player == null || _closed || !_canSeek) return;
    _pendingSeek = null;
    developer.log(
      'Applying a seek asked for during startup. position=$position',
      name: 'iris.player.media',
    );
    unawaited(player.seek(position));
  }

  @override
  void useSkipTimes(List<PlayerSkipSegment> segments) {
    if (_closed) return;
    _lookedUpSegments = List.unmodifiable(segments);
    _refreshPositionOffers();
  }

  /// Jumps to the end of the opening or recap playing now.
  Future<void> skipCurrentSegment() async {
    final segment = skipSegment.value;
    if (segment != null) await seek(segment.end);
  }

  /// Jumps [skipForwardStep] ahead, for files whose opening is unknown.
  Future<void> skipForward() async {
    if (_player == null || _closed) return;
    final duration = player.state.duration;
    final target = player.state.position + skipForwardStep;
    await seek(
      duration > Duration.zero && target > duration ? duration : target,
    );
  }

  @override
  Future<void> stop() async {
    if (_closed) return;
    _startupGeneration++;
    _session = null;
    completed.value = false;
    _resetPositionOffers();
    _stopWatchingPlaybackStats();
    _cancelStartupTimeout();
    _cancelStartupNetworkWatchdog();
    _updateStartupState(const PlayerEngineStartupState.openingSource());
    final player = _player;
    if (player == null) return;

    developer.log('Stopping media_kit playback.', name: 'iris.player.media');
    if (await _stopAndWaitForIdle(player)) return;

    // mpv may still hold the local stream connection; tearing that stream
    // down now could block in a native send(). Disposing the player is
    // guaranteed to close it, at the cost of a new native player.
    developer.log(
      'mpv did not release the stream in time; recreating the player.',
      name: 'iris.player.media',
    );
    await _disposePlayer();
    if (_closed) return;
    _createPlayer();
    notifyListeners();
  }

  Future<bool> _stopAndWaitForIdle(Player player) async {
    try {
      await player.stop();
    } catch (error, stackTrace) {
      developer.log(
        'media_kit failed to stop playback.',
        name: 'iris.player.media',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
    final platform = player.platform;
    if (platform == null) return true;

    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < stopTimeout) {
      try {
        final idle = await (platform as dynamic).getProperty(
          'idle-active',
          waitForInitialization: false,
        );
        if (idle == 'yes') return true;
      } catch (_) {
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return false;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    developer.log('Closing media_kit engine.', name: 'iris.player.media');
    _closed = true;
    _startupGeneration++;
    _cancelStartupTimeout();
    _cancelStartupNetworkWatchdog();
    await _subtitlePreferencesSubscription?.cancel();
    await _decodingPreferencesSubscription?.cancel();
    await _playbackStatsSubscription?.cancel();
    _subtitlePreferencesSubscription = null;
    _decodingPreferencesSubscription = null;
    _playbackStatsSubscription = null;
    await _disposePlayer();
    await _events.close();
    playbackStats.dispose();
    phase.dispose();
    selectedTrack.dispose();
    buffering.dispose();
    bufferMargin.dispose();
    diagnostics.dispose();
    completed.dispose();
    finishing.dispose();
    skipSegment.dispose();
    skipForwardOffered.dispose();
    super.dispose();
  }

  /// Plays [track] and remembers it for the release.
  Future<void> selectAudioTrack(AudioTrack track) async {
    await player.setAudioTrack(track);
    final preferred = preferredAudioTrackFrom(track);
    if (preferred != null) {
      _emit(PlayerEngineTracksChosen(PlayerTrackPreferences(audio: preferred)));
    }
  }

  /// Shows [track] and remembers it for the release.
  Future<void> selectSubtitleTrack(SubtitleTrack track) async {
    await player.setSubtitleTrack(track);
    final preferred = preferredSubtitleTrackFrom(track);
    if (preferred != null) {
      _emit(
        PlayerEngineTracksChosen(PlayerTrackPreferences(subtitle: preferred)),
      );
    }
  }

  void _emit(PlayerEngineEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  @override
  void notifyListeners() {
    if (!_closed) super.notifyListeners();
  }

  void _watchPlaybackStats(String sessionId) {
    if (_statsSessionId == sessionId) return;
    _statsSessionId = sessionId;
    unawaited(_playbackStatsSubscription?.cancel());
    _playbackStatsSubscription = _repository
        .watchPlaybackStats(sessionId: sessionId)
        .listen((stats) {
          if (_closed) return;
          playbackStats.value = stats;
          _updateBufferMargin(stats);
          _trackStartupNetworkActivity(stats);
          unawaited(_logStartupProgress(stats));
          unawaited(_refreshPlaybackDiagnostics());
        });
  }

  /// A stopped file's stats stream ends with the file. The next [open] watches
  /// again, also when it belongs to the same session.
  void _stopWatchingPlaybackStats() {
    unawaited(_playbackStatsSubscription?.cancel());
    _playbackStatsSubscription = null;
    _statsSessionId = null;
    playbackStats.value = null;
  }

  Future<void> _handleSubtitlePreferencesChanged(
    SubtitlePreferences next,
  ) async {
    if (_closed) return;
    final previous = _subtitlePreferences;
    _subtitlePreferences = next;

    if (requiresPlaybackRecreation(
      previousSubtitlePreferences: previous,
      nextSubtitlePreferences: next,
      previousDecodingPreferences: _decodingPreferences,
      nextDecodingPreferences: _decodingPreferences,
    )) {
      await _recreatePlayer();
      return;
    }

    notifyListeners();
    await _applyNativePlayerProperties();
  }

  Future<void> _handleDecodingPreferencesChanged(
    PlayerDecodingPreferences next,
  ) async {
    if (_closed) return;
    final previous = _decodingPreferences;
    _decodingPreferences = next;

    if (requiresPlaybackRecreation(
      previousSubtitlePreferences: _subtitlePreferences,
      nextSubtitlePreferences: _subtitlePreferences,
      previousDecodingPreferences: previous,
      nextDecodingPreferences: next,
    )) {
      await _recreatePlayer();
      return;
    }

    await _applyNativePlayerProperties();
  }

  void _createPlayer() {
    final configuration = buildPlayerRenderingConfiguration(
      _subtitlePreferences,
      _decodingPreferences,
    );
    final player = _playerBuilder(configuration.playerConfiguration);
    _player = player;
    _videoController = _videoControllerBuilder(
      player,
      configuration.videoControllerConfiguration,
    );
    selectedTrack.value = player.state.track;
    buffering.value = player.state.buffering;
    _attachPlayerListeners(player);
  }

  Future<void> _openPlayback() async {
    final session = _session;
    final player = _player;
    if (_closed || session == null || player == null) return;
    final startupGeneration = ++_startupGeneration;
    _startupClock
      ..reset()
      ..start();
    _rebufferCycleTracker.reset();
    _cancelStartupTimeout();
    _cancelStartupNetworkWatchdog();
    _updateStartupState(const PlayerEngineStartupState.openingSource());

    developer.log(
      'Opening media source in media_kit. url=${session.streamUrl}',
      name: 'iris.player.media',
    );
    try {
      await _applyNativePlayerProperties();
      _preferredTracksApplied = false;
      await player.open(Media(session.streamUrl, start: _openPosition));
      if (startupGeneration != _startupGeneration) return;

      developer.log(
        'media_kit opened the stream successfully. Waiting for first frame or timeline metadata.',
        name: 'iris.player.media',
      );
      _transitionToWaitingForFirstFrame(startupGeneration);
    } catch (error, stackTrace) {
      developer.log(
        'media_kit failed to open the stream.',
        name: 'iris.player.media',
        error: error,
        stackTrace: stackTrace,
      );
      if (startupGeneration != _startupGeneration) return;
      _fail(PlayerEngineFailure.generic);
    }
  }

  /// Raises the subtitles mpv draws itself (libass) by [fraction] of the
  /// video's height, clear of controls over the video; 0 puts them back.
  Future<void> liftSubtitles(double fraction) async {
    final lift = fraction.clamp(0.0, 0.6);
    if (lift == _subtitleLift) return;
    _subtitleLift = lift;
    final platform = _player?.platform;
    if (platform == null || _closed) return;
    final position = _liftedSubtitlePosition(
      buildSubtitleMpvProperties(_subtitlePreferences)['sub-pos'],
    );
    if (position == null) return;
    try {
      await (platform as dynamic).setProperty('sub-pos', position);
    } catch (error) {
      developer.log(
        'Failed to move subtitles.',
        name: 'iris.player.media',
        error: error,
      );
    }
  }

  /// mpv's `sub-pos` (percent of the height, 100 = bottom) with the lift.
  String? _liftedSubtitlePosition(String? base) {
    final position = int.tryParse(base ?? '');
    if (position == null) return base;
    final lifted = position - (_subtitleLift * 100).round();
    return lifted.clamp(0, 150).toString();
  }

  Future<void> _applyNativePlayerProperties() async {
    final platform = _player?.platform;
    if (platform == null) return;

    final properties = {
      ...buildPlayerRenderingConfiguration(
        _subtitlePreferences,
        _decodingPreferences,
      ).mpvProperties,
    };
    if (properties['sub-pos'] case final base?) {
      properties['sub-pos'] = _liftedSubtitlePosition(base) ?? base;
    }

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
    if (_player == null) return;
    if (_closed || _reconfiguring) {
      _recreateQueued = true;
      return;
    }

    do {
      _recreateQueued = false;
      developer.log(
        'Recreating media_kit player because native rendering preferences changed. libass=${_subtitlePreferences.libassEnabled} hwdec=${_decodingPreferences.hwdecMode.name}',
        name: 'iris.player.media',
      );
      _reconfiguring = true;
      _updateStartupState(const PlayerEngineStartupState.openingSource());
      notifyListeners();

      await _disposePlayer();
      if (_closed) break;
      _createPlayer();
      notifyListeners();

      await _openPlayback();
    } while (_recreateQueued && !_closed);

    _reconfiguring = false;
    notifyListeners();
  }

  void _attachPlayerListeners(Player player) {
    _playerSubscriptions.addAll([
      player.stream.buffering.listen(_onBuffering),
      player.stream.playing.listen(_onPlaying),
      player.stream.completed.listen(_onCompleted),
      player.stream.position.listen(_onPosition),
      player.stream.duration.listen(_onDuration),
      player.stream.track.listen(_onTrack),
      player.stream.tracks.listen(_onTracks),
      player.stream.error.listen(_onError),
    ]);
  }

  bool get _isReady => _startupState.phase == PlayerEnginePhase.ready;

  void _onBuffering(bool value) {
    if (_closed) return;
    developer.log(
      'media_kit buffering changed: $value',
      name: 'iris.player.media',
    );
    if (value && _isReady && _rebufferCycleTracker.markBufferingStarted()) {
      developer.log(
        'Rebuffer cycle detected. count=${_rebufferCycleTracker.rebufferCount} window=${playerRebufferWindow.inSeconds}s',
        name: 'iris.player.media',
      );
    } else if (!value && _isReady && player.state.playing) {
      _rebufferCycleTracker.markPlaybackStable();
    }
    buffering.value = value;
    unawaited(_logCacheBufferingState('buffering changed'));
  }

  void _onPlaying(bool playing) {
    if (_closed) return;
    developer.log(
      'media_kit playing changed: $playing',
      name: 'iris.player.media',
    );
    if (!_isReady) return;
    if (!playing) _reportProgress(flush: true);
    if (playing && !buffering.value) {
      _rebufferCycleTracker.markPlaybackStable();
      return;
    }
    if (!playing) _rebufferCycleTracker.clearStablePlayback();
  }

  void _onCompleted(bool completed) {
    if (_closed) return;
    developer.log(
      'media_kit completed changed: $completed',
      name: 'iris.player.media',
    );
    // Seeking back from the end clears it.
    this.completed.value = completed && _isReady;
    if (this.completed.value) _emit(const PlayerEngineCompleted());
  }

  void _onPosition(Duration position) {
    if (_closed || !_isReady || _reconfiguring) return;
    // mpv may report zero before the resume seek lands; do not let that
    // overwrite the saved position.
    if (position == Duration.zero && _openPosition != null) return;
    _lastKnownPosition = position;
    _updatePositionOffers(position);
    _reportProgress();
  }

  void _resetPositionOffers() {
    _chapterSegments = const [];
    _lookedUpSegments = const [];
    finishing.value = false;
    skipSegment.value = null;
    skipForwardOffered.value = false;
  }

  void _refreshPositionOffers() {
    final position = _lastKnownPosition;
    if (position != null && _player != null) _updatePositionOffers(position);
  }

  void _updatePositionOffers(Duration position) {
    final duration = player.state.duration;
    if (duration <= Duration.zero) return;
    final segments = _skipSegments;
    skipSegment.value = segments
        .where(
          (segment) =>
              segment.kind != PlayerSkipKind.ending &&
              segment.contains(position),
        )
        .firstOrNull;
    skipForwardOffered.value =
        position < _skipForwardWindow &&
        !segments.any((segment) => segment.kind == PlayerSkipKind.opening);
    finishing.value = position >= _finishingStart(segments, duration);
  }

  /// The ending's start when known (an "ending" in the first half is a
  /// misnamed chapter), otherwise the point where the file counts as
  /// watched.
  Duration _finishingStart(
    List<PlayerSkipSegment> segments,
    Duration duration,
  ) {
    for (final segment in segments) {
      if (segment.kind == PlayerSkipKind.ending &&
          segment.start >= duration ~/ 2) {
        return segment.start;
      }
    }
    return duration * WatchProgress.finishedFraction;
  }

  /// Reads the chapters mpv found in the file; BD rips usually name the
  /// opening and the ending.
  Future<void> _loadChapters(int startupGeneration) async {
    final count =
        int.tryParse(
          await _readNativeStringProperty('chapter-list/count') ?? '',
        ) ??
        0;
    final chapters = <PlayerChapter>[];
    for (var index = 0; index < count; index++) {
      final title = await _readNativeStringProperty(
        'chapter-list/$index/title',
      );
      final seconds = double.tryParse(
        await _readNativeStringProperty('chapter-list/$index/time') ?? '',
      );
      // The reader drops "0", which is the first chapter's time.
      if (title == null || (seconds == null && index > 0)) continue;
      chapters.add(
        PlayerChapter(
          title: title,
          start: Duration(milliseconds: ((seconds ?? 0) * 1000).round()),
        ),
      );
    }
    if (_closed || startupGeneration != _startupGeneration) return;
    _chapterSegments = skipSegmentsFromChapters(
      chapters,
      player.state.duration,
    );
    developer.log(
      'Chapters read. count=${chapters.length} skip=$_chapterSegments',
      name: 'iris.player.media',
    );
    _refreshPositionOffers();
  }

  void _onDuration(Duration duration) {
    if (_closed) return;
    final hasDuration = duration > Duration.zero;
    if (_startupState.hasDuration == hasDuration) return;

    developer.log(
      'media_kit duration metadata changed. duration=$duration hasDuration=$hasDuration',
      name: 'iris.player.media',
    );
    _updateStartupState(_startupState.copyWith(hasDuration: hasDuration));
    _applyPendingSeek();
    _markReadyIfPrepared();
  }

  void _onTrack(Track track) {
    if (_closed || selectedTrack.value == track) return;
    developer.log(
      'media_kit selected tracks changed. video=${track.video.codec} audio=${track.audio.codec} subtitle=${track.subtitle.codec}',
      name: 'iris.player.media',
    );
    selectedTrack.value = track;
  }

  void _onTracks(Tracks tracks) {
    if (_closed) return;
    unawaited(_applyPreferredTracks(tracks));
    final hasVideoTrack = _hasRealVideoTrack(tracks);
    if (_startupState.hasVideoTrack == hasVideoTrack) return;

    developer.log(
      'media_kit available video tracks changed. count=${tracks.video.length} hasVideoTrack=$hasVideoTrack',
      name: 'iris.player.media',
    );
    _updateStartupState(_startupState.copyWith(hasVideoTrack: hasVideoTrack));
    _markReadyIfPrepared();
  }

  void _onError(String error) {
    if (_closed) return;
    developer.log(
      'media_kit emitted player error: $error',
      name: 'iris.player.media',
    );
    final fallback = resolveAudioFallbackTrack(
      errorMessage: error,
      audioTracks: player.state.tracks.audio,
      selectedAudioTrack: player.state.track.audio,
    );
    if (fallback != null && !_recoveringAudioTrack) {
      developer.log(
        'Attempting audio fallback after decoder error. selected=${player.state.track.audio.codec} fallback=${fallback.codec} fallbackId=${fallback.id}',
        name: 'iris.player.media',
      );
      unawaited(_recoverFromUnsupportedAudio(fallback));
      return;
    }
    // Errors of a stopped file (between files) are not playback failures.
    if (_session == null) return;
    _fail(PlayerEngineFailure.generic);
  }

  void _reportProgress({bool flush = false}) {
    final position = _lastKnownPosition;
    final duration = player.state.duration;
    if (position == null || duration <= Duration.zero) return;
    _emit(PlayerEngineProgress(position, duration, flush: flush));
  }

  /// Applies the release's remembered audio/subtitle choice once per opened
  /// file, as soon as its tracks are known.
  Future<void> _applyPreferredTracks(Tracks tracks) async {
    final preferences = _preferredTracks;
    if (_preferredTracksApplied || preferences == null || preferences.isEmpty) {
      return;
    }
    final hasChoices = tracks.audio.length > 2 || tracks.subtitle.length > 2;
    if (!hasChoices) return;
    _preferredTracksApplied = true;

    try {
      final audio = preferences.audio;
      final audioTrack = audio == null
          ? null
          : matchAudioTrack(tracks.audio, audio);
      if (audioTrack != null && audioTrack != player.state.track.audio) {
        await player.setAudioTrack(audioTrack);
      }
      final subtitle = preferences.subtitle;
      final subtitleTrack = subtitle == null
          ? null
          : matchSubtitleTrack(tracks.subtitle, subtitle);
      if (subtitleTrack != null &&
          subtitleTrack != player.state.track.subtitle) {
        await player.setSubtitleTrack(subtitleTrack);
      }
    } catch (error, stackTrace) {
      developer.log(
        'Unable to apply remembered tracks.',
        name: 'iris.player.media',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _recoverFromUnsupportedAudio(AudioTrack fallbackTrack) async {
    if (_closed) return;
    _recoveringAudioTrack = true;
    try {
      await player.setAudioTrack(fallbackTrack);
      await player.play();
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
      if (!_closed) _fail(PlayerEngineFailure.generic);
    } finally {
      _recoveringAudioTrack = false;
    }
  }

  void _transitionToWaitingForFirstFrame(int startupGeneration) {
    if (_closed || startupGeneration != _startupGeneration) return;

    _updateStartupState(
      _startupState.copyWith(phase: PlayerEnginePhase.waitingForFirstFrame),
    );
    _startStartupNetworkWatchdog(startupGeneration);
    _startupTimeoutTimer = Timer(startupTimeout, () {
      unawaited(_handleStartupTimeout(startupGeneration));
    });
    unawaited(_awaitFirstFrame(startupGeneration));
    _markReadyIfPrepared();
  }

  Future<void> _awaitFirstFrame(int startupGeneration) async {
    try {
      await _firstFrameAwaiter(videoController);
      if (_closed || startupGeneration != _startupGeneration) return;

      developer.log(
        'media_kit rendered the first frame successfully. '
        't=${(_startupClock.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
        name: 'iris.player.media',
      );
      _updateStartupState(_startupState.copyWith(firstFrameRendered: true));
      _markReadyIfPrepared();
    } catch (error, stackTrace) {
      if (_closed || startupGeneration != _startupGeneration) return;
      developer.log(
        'media_kit failed while waiting for the first frame.',
        name: 'iris.player.media',
        error: error,
        stackTrace: stackTrace,
      );
      _fail(PlayerEngineFailure.generic);
    }
  }

  Future<void> _handleStartupTimeout(int startupGeneration) async {
    if (_closed ||
        startupGeneration != _startupGeneration ||
        _startupState.phase != PlayerEnginePhase.waitingForFirstFrame) {
      return;
    }

    await _logCacheBufferingState('first frame timeout');
    developer.log(
      'media_kit startup timed out before the first frame was ready. hasDuration=${_startupState.hasDuration} hasVideoTrack=${_startupState.hasVideoTrack} firstFrameRendered=${_startupState.firstFrameRendered}',
      name: 'iris.player.media',
    );
    _fail(PlayerEngineFailure.firstFrameTimeout);
  }

  void _markReadyIfPrepared() {
    if (_startupState.phase != PlayerEnginePhase.waitingForFirstFrame) return;

    final hasFallbackReadiness =
        _startupState.hasDuration && _startupState.hasVideoTrack;
    if (!_startupState.firstFrameRendered && !hasFallbackReadiness) return;

    final readinessReason = _startupState.firstFrameRendered
        ? 'first-frame'
        : 'timeline-fallback';
    developer.log(
      'media_kit playback is ready. reason=$readinessReason firstFrameRendered=${_startupState.firstFrameRendered} hasDuration=${_startupState.hasDuration} hasVideoTrack=${_startupState.hasVideoTrack}',
      name: 'iris.player.media',
    );
    _cancelStartupTimeout();
    _cancelStartupNetworkWatchdog();
    _updateStartupState(_startupState.copyWith(phase: PlayerEnginePhase.ready));
    _applyPendingSeek();
    if (player.state.playing && !buffering.value) {
      _rebufferCycleTracker.markPlaybackStable();
    }
    unawaited(_loadChapters(_startupGeneration));
  }

  void _fail(PlayerEngineFailure failure) {
    _cancelStartupTimeout();
    _cancelStartupNetworkWatchdog();
    _updateStartupState(
      _startupState.copyWith(phase: PlayerEnginePhase.failed, failure: failure),
    );
  }

  void _updateStartupState(PlayerEngineStartupState next) {
    if (next == _startupState) return;
    _startupState = next;
    if (!_closed) phase.value = next.phase;
    notifyListeners();
    // A picture on screen is when the file has started for the viewer.
    if (!_startAnnounced &&
        next.phase == PlayerEnginePhase.ready &&
        next.firstFrameRendered) {
      _startAnnounced = true;
      _emit(const PlayerEnginePlaybackStarted());
    }
  }

  void _cancelStartupTimeout() {
    _startupTimeoutTimer?.cancel();
    _startupTimeoutTimer = null;
  }

  void _trackStartupNetworkActivity(PlayerPlaybackStats stats) {
    if (_startupState.phase == PlayerEnginePhase.ready ||
        _startupState.phase == PlayerEnginePhase.failed) {
      return;
    }

    _startupNetworkMonitoringElapsed ??= Duration.zero;
    if (stats.downloadRateBytesPerSecond > 0 || stats.activePeers > 0) {
      _lastStartupNetworkActivityAt = _startupNetworkMonitoringElapsed;
    }
  }

  void _startStartupNetworkWatchdog(int startupGeneration) {
    if (_startupNetworkWatchdogTimer != null) return;

    _startupNetworkWatchdogTimer = Timer.periodic(const Duration(seconds: 1), (
      _,
    ) {
      if (_closed ||
          startupGeneration != _startupGeneration ||
          _startupState.phase == PlayerEnginePhase.ready ||
          _startupState.phase == PlayerEnginePhase.failed) {
        _cancelStartupNetworkWatchdog();
        return;
      }

      final monitoringElapsed = _startupNetworkMonitoringElapsed;
      if (monitoringElapsed == null) return;

      final nextElapsed = monitoringElapsed + const Duration(seconds: 1);
      _startupNetworkMonitoringElapsed = nextElapsed;

      final lastActivityAt = _lastStartupNetworkActivityAt ?? Duration.zero;
      if (nextElapsed - lastActivityAt < const Duration(seconds: 15)) return;

      developer.log(
        'media_kit startup failed because torrent stream never showed network activity.',
        name: 'iris.player.media',
      );
      _fail(PlayerEngineFailure.transportStartupTimeout);
    });
  }

  void _cancelStartupNetworkWatchdog() {
    _startupNetworkWatchdogTimer?.cancel();
    _startupNetworkWatchdogTimer = null;
    _startupNetworkMonitoringElapsed = null;
    _lastStartupNetworkActivityAt = null;
  }

  void _updateBufferMargin(PlayerPlaybackStats stats) {
    final next = resolvePlayerBufferMargin(stats);
    if (next != bufferMargin.value) bufferMargin.value = next;
  }

  /// mpv's view of a starting stream: where it reads the file, what its
  /// cache holds, and whether it waits for data.
  static const _startupMpvProperties = [
    'stream-pos',
    'file-size',
    'time-pos',
    'demuxer-cache-time',
    'demuxer-cache-duration',
    'cache-buffering-state',
    'paused-for-cache',
    'core-idle',
  ];

  /// Until the first picture, a line per stats update: what the torrent
  /// delivers next to what mpv has, to tell a slow swarm from a demuxer
  /// waiting on data elsewhere in the file.
  Future<void> _logStartupProgress(PlayerPlaybackStats stats) async {
    final state = _startupState;
    if (state.firstFrameRendered ||
        state.phase == PlayerEnginePhase.failed ||
        !_startupClock.isRunning) {
      return;
    }
    final elapsed = _startupClock.elapsedMilliseconds / 1000;
    final platform = _player?.platform;
    final mpv = <String>[];
    if (platform != null) {
      for (final name in _startupMpvProperties) {
        try {
          final value = await (platform as dynamic).getProperty(
            name,
            waitForInitialization: false,
          );
          mpv.add('$name=$value');
        } catch (_) {}
      }
    }
    developer.log(
      'Startup progress. t=${elapsed.toStringAsFixed(1)}s '
      'phase=${state.phase.name} '
      'rate=${stats.downloadRateBytesPerSecond ~/ 1024}KB/s '
      'peers=${stats.activePeers} '
      'buffer=${stats.bufferPieces}/${stats.readaheadWindow} pieces '
      '${stats.bufferSeconds.toStringAsFixed(1)}s '
      'mpv: ${mpv.join(' ')}',
      name: 'iris.player.startup',
    );
  }

  Future<void> _logCacheBufferingState(String reason) async {
    final platform = _player?.platform;
    if (platform == null) return;

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

  Future<void> _refreshPlaybackDiagnostics() async {
    if (_closed) return;
    if (_player?.platform == null) {
      diagnostics.value = null;
      return;
    }

    final next = PlayerPlaybackDiagnostics(
      hwdecCurrent: await _readNativeStringProperty('hwdec-current'),
      currentVo: await _readNativeStringProperty('current-vo'),
      videoCodec: await _readNativeStringProperty('current-tracks/video/codec'),
      videoDecoder: await _readNativeStringProperty(
        'current-tracks/video/decoder',
      ),
      videoDecoderDescription: await _readNativeStringProperty(
        'current-tracks/video/decoder-desc',
      ),
    );
    if (_closed) return;

    final value = next.isEmpty ? null : next;
    if (diagnostics.value != value) diagnostics.value = value;
  }

  Future<String?> _readNativeStringProperty(String property) async {
    final platform = _player?.platform;
    if (platform == null) return null;

    try {
      final value = await (platform as dynamic).getProperty(
        property,
        waitForInitialization: false,
      );
      if (value is! String) return null;
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == '0') return null;
      return trimmed;
    } catch (_) {
      return null;
    }
  }

  Future<void> _disposePlayer() async {
    _cancelStartupTimeout();
    _cancelStartupNetworkWatchdog();
    final subscriptions = List.of(_playerSubscriptions);
    _playerSubscriptions.clear();
    if (!_closed) diagnostics.value = null;
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    final player = _player;
    // The old controller stays until a new one replaces it, so the viewport
    // never renders without one.
    _player = null;
    await player?.dispose();
  }
}

bool _hasRealVideoTrack(Tracks tracks) {
  return tracks.video.any((track) => track.id != 'auto' && track.id != 'no');
}

Player _defaultPlayerBuilder(PlayerConfiguration configuration) {
  return Player(configuration: configuration);
}

VideoController _defaultVideoControllerBuilder(
  Player player,
  VideoControllerConfiguration configuration,
) {
  return VideoController(player, configuration: configuration);
}

Future<void> _defaultFirstFrameAwaiter(VideoController controller) {
  return controller.waitUntilFirstFrameRendered;
}
