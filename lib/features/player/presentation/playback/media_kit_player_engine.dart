import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:iris/features/online_sources/domain/online_stream_choice.dart';
import 'package:iris/features/online_sources/domain/repositories/online_quality_preferences.dart';
import 'package:iris/features/player/presentation/playback/player_quality_choice.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';
import 'package:iris/features/player/domain/entities/player_playback_diagnostics.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/entities/player_track_preferences.dart';
import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/domain/player_chapter_skip_segments.dart';
import 'package:iris/features/player/domain/player_timeline_parts.dart';
import 'package:iris/shared/utils/equality.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/playback/player_engine.dart';
import 'package:iris/features/player/presentation/playback/player_audio_fallback_resolver.dart';
import 'package:iris/features/player/presentation/playback/player_buffer_margin.dart';
import 'package:iris/features/player/presentation/playback/player_subtitle_preferences_mapper.dart';
import 'package:iris/features/player/presentation/playback/player_track_matcher.dart';

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

enum PlayerEngineFailure { generic, firstFrameTimeout }

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
    OnlineQualityPreferences? onlineQuality,
    MediaKitPlayerBuilder? playerBuilder,
    MediaKitVideoControllerBuilder? videoControllerBuilder,
    MediaKitFirstFrameAwaiter? firstFrameAwaiter,
    this.startupTimeout = const Duration(seconds: 45),
    this.stopTimeout = const Duration(seconds: 3),
    this.errorGrace = const Duration(seconds: 2),
  }) : _repository = repository,
       _onlineQuality = onlineQuality,
       _playerBuilder = playerBuilder ?? _defaultPlayerBuilder,
       _videoControllerBuilder =
           videoControllerBuilder ?? _defaultVideoControllerBuilder,
       _firstFrameAwaiter = firstFrameAwaiter ?? _defaultFirstFrameAwaiter,
       _subtitlePreferences = subtitlePreferences.state,
       _decodingPreferences = decodingPreferences.state {
    _subtitlePreferencesSubscription = subtitlePreferences.stream.listen(
      (preferences) =>
          unawaited(_onRenderingPreferencesChanged(subtitles: preferences)),
    );
    _decodingPreferencesSubscription = decodingPreferences.stream.listen(
      (preferences) =>
          unawaited(_onRenderingPreferencesChanged(decoding: preferences)),
    );
  }

  final PlayerRepository _repository;

  /// Where the quality chosen for watching online is kept; null where
  /// there is no choice to offer.
  final OnlineQualityPreferences? _onlineQuality;
  final MediaKitPlayerBuilder _playerBuilder;
  final MediaKitVideoControllerBuilder _videoControllerBuilder;
  final MediaKitFirstFrameAwaiter _firstFrameAwaiter;

  /// How long the first frame may take before startup fails.
  final Duration startupTimeout;

  /// How long [stop] waits for mpv to close the stream before it disposes
  /// the player instead.
  final Duration stopTimeout;

  /// How long after an error mpv logs the file is checked: the file it
  /// ends goes within that, a hiccup it gets over stays.
  final Duration errorGrace;

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

  /// Where the file being opened should start; checked once it is ready.
  Duration? _openTarget;

  /// How far mpv may land from [_openTarget] before it is sent there.
  static const _openTolerance = Duration(seconds: 5);

  /// Whether [PlayerEnginePlaybackStarted] went out for the open file.
  bool _startAnnounced = false;

  /// The file has played since it was opened or its link was last renewed:
  /// a link that fails now may have expired, so it is renewed once before
  /// the failure shows.
  bool _renewsOnFailure = false;

  /// Renewals left for the opened file: a server whose every link plays a
  /// moment and dies is not asked for ever.
  int _renewalsLeft = _maxRenewals;
  static const _maxRenewals = 3;

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

  PlayerEngineStartupState _startupState =
      const PlayerEngineStartupState.openingSource();
  Timer? _startupTimeoutTimer;
  int _startupGeneration = 0;
  Timer? _errorCheckTimer;

  /// Reads the decoder state while a file is open, whatever carries it:
  /// an online stream has no transport stats to piggyback on.
  Timer? _diagnosticsTimer;
  static const _diagnosticsInterval = Duration(seconds: 2);

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

  /// The qualities the playing file comes in and the chosen one; null when
  /// it has no choice (a torrent, a download).
  final quality = ValueNotifier<PlayerQualityChoice?>(null);

  /// Playback reached the ending, or, when its start is unknown, the point
  /// where the file counts as watched.
  final finishing = ValueNotifier<bool>(false);

  /// [PlayerEngineWatched] went out for the opened file.
  bool _watchedReported = false;

  /// The opening or recap playing now, when its end is known.
  final skipSegment = ValueNotifier<PlayerSkipSegment?>(null);

  /// The opened file cut into its chapters, or around its looked-up
  /// opening and ending; empty while neither is known.
  final timeline = ValueNotifier<List<PlayerTimelinePart>>(const []);

  /// The opening is unknown and the file has just started: a fixed jump of
  /// [skipForwardStep] is offered instead.
  final skipForwardOffered = ValueNotifier<bool>(false);

  /// A TV opening runs about 90 s; a little less never skips story.
  static const skipForwardStep = Duration(seconds: 85);

  /// Openings come within the first minutes, after a cold open at most.
  static const _skipForwardWindow = Duration(minutes: 5);

  final _playbackRate = ValueNotifier<double>(1);
  bool _fastForwardHeld = false;

  /// The fast-forward hold's speed, unless the chosen one is faster.
  static const fastForwardRate = 2.0;

  @override
  ValueListenable<double> get playbackRate => _playbackRate;

  double get _effectiveRate => _fastForwardHeld
      ? math.max(fastForwardRate, _playbackRate.value)
      : _playbackRate.value;

  List<PlayerChapter> _chapters = const [];
  List<PlayerSkipSegment> _chapterSegments = const [];
  List<PlayerSkipSegment> _lookedUpSegments = const [];
  bool _skipTimesPending = false;

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
    _refreshQualityChoice();
    _startPosition = startPosition;
    _preferredTracks = preferredTracks;
    _preferredTracksApplied = false;
    _lastKnownPosition = null;
    _pendingSeek = null;
    _startAnnounced = false;
    _renewsOnFailure = false;
    _renewalsLeft = _maxRenewals;
    completed.value = false;
    _resetPositionOffers();
    _watchPlaybackStats(session.sessionId);
    _watchDiagnostics();
    // Synchronous on purpose: the viewport can render the controller as soon
    // as this returns.
    if (_player == null) _createPlayer();
    return _openPlayback();
  }

  /// Opens the current file again after a failure, on a fresh link when
  /// its backend issues links that expire.
  Future<void> retry() async {
    final session = _session;
    if (_closed || session == null) return;
    final startupGeneration = _startupGeneration;
    _updateStartupState(const PlayerEngineStartupState.openingSource());
    await _renewSession(session);
    // Stopped, or another file opened, while the link was asked for.
    if (_closed || startupGeneration != _startupGeneration) return;
    await _openPlayback();
  }

  /// Swaps [session] for a fresh link when its backend gives one; false
  /// when it gives none or fails, or the file changed meanwhile.
  Future<bool> _renewSession(PlayerSession session) async {
    final PlayerSession? renewed;
    try {
      renewed = await _repository.renewSession(session);
    } catch (error) {
      developer.log(
        'The stream link could not be renewed.',
        name: 'iris.player.media',
        error: error,
      );
      return false;
    }
    if (renewed == null || _closed || !identical(_session, session)) {
      return false;
    }
    _session = renewed;
    _refreshQualityChoice();
    return true;
  }

  /// Watches online episodes in [height] (null: the best) from now on, and
  /// reopens the playing one in it where it is. While the new link is asked
  /// for, the old one plays on; if none comes, it stays.
  Future<void> chooseQuality(int? height) async {
    final preferences = _onlineQuality;
    final session = _session;
    if (_closed ||
        preferences == null ||
        session == null ||
        session.qualities.isEmpty) {
      return;
    }
    await preferences.setWatching(height);
    _refreshQualityChoice();
    if (closestQuality(session.qualities, height) == session.quality) return;
    final startupGeneration = _startupGeneration;
    if (!await _renewSession(session) ||
        _closed ||
        startupGeneration != _startupGeneration) {
      return;
    }
    developer.log(
      'Reopening the file in ${_session?.quality}p at $_openPosition.',
      name: 'iris.player.media',
    );
    await _openPlayback();
  }

  void _refreshQualityChoice() {
    if (_closed) return;
    final session = _session;
    final offered = session?.qualities ?? const <int>[];
    if (session == null || offered.isEmpty || _onlineQuality == null) {
      quality.value = null;
      return;
    }
    final wanted = _onlineQuality.watching;
    quality.value = PlayerQualityChoice(
      offered: offered,
      // A height this file lacks shows as the one it plays in.
      selected: wanted == null || offered.contains(wanted)
          ? wanted
          : session.quality,
    );
  }

  /// A file that played was dropped: reopens it where it was on a fresh
  /// link, or shows the failure when there is none.
  Future<void> _reopenOnFreshLink(int startupGeneration) async {
    final session = _session;
    if (session == null) return;
    _renewsOnFailure = false;
    _updateStartupState(const PlayerEngineStartupState.openingSource());
    final renewed = await _renewSession(session);
    if (_closed || startupGeneration != _startupGeneration) return;
    if (!renewed) {
      _fail(PlayerEngineFailure.generic);
      return;
    }
    developer.log(
      'Reopening the file on a renewed link at $_openPosition.',
      name: 'iris.player.media',
    );
    await _openPlayback();
  }

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
  void expectSkipTimes() {
    if (_closed) return;
    _skipTimesPending = true;
    _refreshPositionOffers();
  }

  @override
  void useSkipTimes(List<PlayerSkipSegment> segments) {
    if (_closed) return;
    _skipTimesPending = false;
    _lookedUpSegments = List.unmodifiable(segments);
    _refreshTimeline();
    _refreshPositionOffers();
  }

  @override
  void setPlaybackRate(double rate) {
    if (_closed || rate <= 0 || rate == _playbackRate.value) return;
    _playbackRate.value = rate;
    unawaited(_applyPlaybackRate());
  }

  @override
  void holdFastForward(bool held) {
    if (_closed || held == _fastForwardHeld) return;
    _fastForwardHeld = held;
    unawaited(_applyPlaybackRate());
  }

  /// Sends the speed to mpv, which keeps it from file to file; a new native
  /// player starts at 1 and gets it again when it opens the file.
  Future<void> _applyPlaybackRate() async {
    final player = _player;
    final rate = _effectiveRate;
    if (_closed || player == null || player.state.rate == rate) return;
    try {
      await player.setRate(rate);
    } catch (error) {
      developer.log(
        'Failed to change the playback speed.',
        name: 'iris.player.media',
        error: error,
      );
    }
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
    _refreshQualityChoice();
    _renewsOnFailure = false;
    completed.value = false;
    _resetPositionOffers();
    _stopWatchingPlaybackStats();
    _stopWatchingDiagnostics();
    _cancelStartupTimeout();
    _cancelErrorCheck();
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
        final idle = await _getMpvProperty(platform, 'idle-active');
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
    _cancelErrorCheck();
    _stopWatchingDiagnostics();
    await _subtitlePreferencesSubscription?.cancel();
    await _decodingPreferencesSubscription?.cancel();
    // Not awaited: a stats poll may end only at its next tick, and the
    // listener already ignores what comes after close.
    unawaited(_playbackStatsSubscription?.cancel());
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
    quality.dispose();
    finishing.dispose();
    skipSegment.dispose();
    timeline.dispose();
    skipForwardOffered.dispose();
    _playbackRate.dispose();
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
          unawaited(_logStartupProgress(stats));
        });
  }

  void _watchDiagnostics() {
    _diagnosticsTimer?.cancel();
    _diagnosticsTimer = Timer.periodic(
      _diagnosticsInterval,
      (_) => unawaited(_refreshPlaybackDiagnostics()),
    );
  }

  void _stopWatchingDiagnostics() {
    _diagnosticsTimer?.cancel();
    _diagnosticsTimer = null;
  }

  /// A stopped file's stats stream ends with the file. The next [open] watches
  /// again, also when it belongs to the same session.
  void _stopWatchingPlaybackStats() {
    unawaited(_playbackStatsSubscription?.cancel());
    _playbackStatsSubscription = null;
    _statsSessionId = null;
    playbackStats.value = null;
  }

  Future<void> _onRenderingPreferencesChanged({
    SubtitlePreferences? subtitles,
    PlayerDecodingPreferences? decoding,
  }) async {
    if (_closed) return;
    final previousSubtitles = _subtitlePreferences;
    final previousDecoding = _decodingPreferences;
    _subtitlePreferences = subtitles ?? previousSubtitles;
    _decodingPreferences = decoding ?? previousDecoding;

    if (requiresPlaybackRecreation(
      previousSubtitlePreferences: previousSubtitles,
      nextSubtitlePreferences: _subtitlePreferences,
      previousDecodingPreferences: previousDecoding,
      nextDecodingPreferences: _decodingPreferences,
    )) {
      await _recreatePlayer();
      return;
    }

    // The Flutter subtitle view reads [subtitleViewConfiguration].
    if (subtitles != null) notifyListeners();
    await _applyMpvProperties(_subtitleMpvProperties);
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
    _cancelStartupTimeout();
    _cancelErrorCheck();
    _updateStartupState(const PlayerEngineStartupState.openingSource());

    developer.log(
      'Opening media source in media_kit. url=${session.streamUrl}',
      name: 'iris.player.media',
    );
    try {
      await _applyMpvProperties({
        ...playbackMpvProperties,
        ..._subtitleMpvProperties,
      });
      await _applyPlaybackRate();
      _preferredTracksApplied = false;
      _openTarget = _openPosition;
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
    try {
      await _setMpvProperty(platform, 'sub-pos', _liftedSubtitlePosition);
    } catch (error) {
      developer.log(
        'Failed to move subtitles.',
        name: 'iris.player.media',
        error: error,
      );
    }
  }

  /// mpv's `sub-pos` (percent of the height, 100 = bottom) with the lift.
  String get _liftedSubtitlePosition {
    final position = subtitleMpvPosition(_subtitlePreferences.verticalPosition);
    final lifted = position - (_subtitleLift * 100).round();
    return lifted.clamp(0, 150).toString();
  }

  Map<String, String> get _subtitleMpvProperties => {
    ...buildSubtitleMpvProperties(_subtitlePreferences),
    'sub-pos': _liftedSubtitlePosition,
  };

  Future<void> _applyMpvProperties(Map<String, String> properties) async {
    final platform = _player?.platform;
    if (platform == null) return;

    try {
      for (final entry in properties.entries) {
        await _setMpvProperty(platform, entry.key, entry.value);
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
    _chapters = const [];
    timeline.value = const [];
    _chapterSegments = const [];
    _lookedUpSegments = const [];
    _skipTimesPending = false;
    finishing.value = false;
    _watchedReported = false;
    skipSegment.value = null;
    skipForwardOffered.value = false;
  }

  void _refreshTimeline() {
    final parts = timelineParts(
      chapters: _chapters,
      segments: _lookedUpSegments,
      duration: _player?.state.duration ?? Duration.zero,
    );
    if (!sameList(parts, timeline.value)) timeline.value = parts;
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
        !_skipTimesPending &&
        !segments.any((segment) => segment.kind == PlayerSkipKind.opening);
    finishing.value = position >= _finishingStart(segments, duration);
    if (finishing.value && !_watchedReported) {
      _watchedReported = true;
      _emit(const PlayerEngineWatched());
    }
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
      if (seconds == null && index > 0) continue;
      chapters.add(
        PlayerChapter(
          // Untitled chapters still end the one before them.
          title: title ?? '',
          start: Duration(milliseconds: ((seconds ?? 0) * 1000).round()),
        ),
      );
    }
    if (_closed || startupGeneration != _startupGeneration) return;
    _chapters = List.unmodifiable(chapters);
    _refreshTimeline();
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
    _refreshTimeline();
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
    // mpv logs a hiccup it gets over (a segment that did not load, a frame
    // that did not decode) as it logs one that ends the file: only a file
    // mpv let go of is a failure.
    final startupGeneration = _startupGeneration;
    _errorCheckTimer?.cancel();
    _errorCheckTimer = Timer(errorGrace, () {
      unawaited(_failIfFileDropped(startupGeneration));
    });
  }

  Future<void> _failIfFileDropped(int startupGeneration) async {
    final platform = _player?.platform;
    if (_closed ||
        platform == null ||
        startupGeneration != _startupGeneration ||
        _startupState.phase == PlayerEnginePhase.failed) {
      return;
    }
    final String idle;
    try {
      idle = '${await _getMpvProperty(platform, 'idle-active')}';
    } catch (_) {
      return;
    }
    if (_closed || startupGeneration != _startupGeneration) return;
    if (idle != 'yes') {
      developer.log(
        'mpv kept the file after an error; playback goes on.',
        name: 'iris.player.media',
      );
      return;
    }
    developer.log(
      'mpv dropped the file after an error.',
      name: 'iris.player.media',
    );
    if (_renewsOnFailure && _renewalsLeft > 0) {
      _renewalsLeft--;
      await _reopenOnFreshLink(startupGeneration);
      return;
    }
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
    _renewsOnFailure = true;
    _updateStartupState(_startupState.copyWith(phase: PlayerEnginePhase.ready));
    // A seek asked for during startup decides where playback is.
    if (_pendingSeek != null) _openTarget = null;
    _applyPendingSeek();
    unawaited(_checkOpenedAt(_startupGeneration));
    unawaited(_loadChapters(_startupGeneration));
  }

  /// The video gives way to the error; mpv, which may still get the file
  /// going, is paused, so nothing plays behind it. Retry opens it anew.
  /// mpv does not start every stream where asked (some HLS opens at 0
  /// whatever the start), so once the file is ready it is sent there.
  Future<void> _checkOpenedAt(int startupGeneration) async {
    final target = _openTarget;
    _openTarget = null;
    final player = _player;
    final platform = player?.platform;
    if (target == null || player == null || platform == null) return;
    final double? seconds;
    try {
      seconds = double.tryParse(
        '${await _getMpvProperty(platform, 'time-pos')}',
      );
    } catch (_) {
      return;
    }
    if (seconds == null ||
        _closed ||
        startupGeneration != _startupGeneration ||
        _pendingSeek != null) {
      return;
    }
    final actual = Duration(milliseconds: (seconds * 1000).round());
    if ((actual - target).abs() <= _openTolerance) return;
    developer.log(
      'mpv opened the file at $actual instead of $target; seeking there.',
      name: 'iris.player.media',
    );
    await player.seek(target);
  }

  void _fail(PlayerEngineFailure failure) {
    _cancelStartupTimeout();
    _cancelErrorCheck();
    final player = _player;
    if (player != null) {
      unawaited(
        player.pause().catchError((Object error) {
          developer.log(
            'media_kit failed to pause a failed file.',
            name: 'iris.player.media',
            error: error,
          );
        }),
      );
    }
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

  void _cancelErrorCheck() {
    _errorCheckTimer?.cancel();
    _errorCheckTimer = null;
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
          final value = await _getMpvProperty(platform, name);
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
      final cacheBufferingState = await _getMpvProperty(
        platform,
        'cache-buffering-state',
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
      final value = await _getMpvProperty(platform, property);
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

/// mpv's own property access, which [PlatformPlayer] does not declare.
Future<Object?> _getMpvProperty(PlatformPlayer platform, String name) async {
  return await (platform as dynamic).getProperty(
    name,
    waitForInitialization: false,
  );
}

Future<void> _setMpvProperty(
  PlatformPlayer platform,
  String name,
  String value,
) async {
  await (platform as dynamic).setProperty(name, value);
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
