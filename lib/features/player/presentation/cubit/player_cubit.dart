import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress_repository.dart';
import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_track_preferences.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/domain/repositories/player_skip_times_repository.dart';
import 'package:iris/features/player/domain/repositories/player_track_preferences_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';
import 'package:iris/features/player/presentation/playback/player_engine.dart';

/// Owns the page's playback: the torrent stream (through the repository)
/// and the media player ([PlayerEngine]), and keeps them in order — the
/// player releases a stream before the stream is torn down.
class PlayerCubit extends Cubit<PlayerState> {
  PlayerCubit({
    required AnimePlayerSource source,
    required PlayerRepository repository,
    required PlayerEngine engine,
    WatchProgressRepository? progressRepository,
    PlayerTrackPreferencesRepository? trackPreferencesRepository,
    PlayerSkipTimesRepository? skipTimesRepository,
    DateTime Function() now = DateTime.now,
    this.engineReleaseTimeout = const Duration(seconds: 5),
    this.progressSaveInterval = const Duration(seconds: 10),
  }) : _source = source,
       _repository = repository,
       _engine = engine,
       _progressRepository = progressRepository,
       _trackPreferencesRepository = trackPreferencesRepository,
       _skipTimesRepository = skipTimesRepository,
       _now = now,
       super(const PlayerInitial()) {
    _engineEvents = engine.events.listen(_handleEngineEvent);
  }

  final PlayerRepository _repository;
  final PlayerEngine _engine;
  late final StreamSubscription<PlayerEngineEvent> _engineEvents;
  final WatchProgressRepository? _progressRepository;
  final PlayerTrackPreferencesRepository? _trackPreferencesRepository;
  final PlayerSkipTimesRepository? _skipTimesRepository;
  final DateTime Function() _now;

  /// Upper bound for waiting on the media player to release a stream.
  final Duration engineReleaseTimeout;

  /// How often the playback position is persisted while playing.
  final Duration progressSaveInterval;

  AnimePlayerSource _source;
  WatchProgress? _savedProgress;
  bool _progressLoaded = false;
  Duration? _startPosition;

  /// The media player has opened a file; from then on it stays on screen,
  /// also while the next file starts.
  bool _engineOpened = false;
  Duration? _lastPosition;
  Duration? _lastDuration;
  DateTime? _lastSavedAt;
  PlayerTrackPreferences? _trackPreferences;
  bool _trackPreferencesLoaded = false;
  bool _switchingFile = false;
  bool _skipTimesRequested = false;

  /// The file currently being played.
  AnimePlayerSource get source => _source;

  PlayerEngine get engine => _engine;

  /// Remembered audio/subtitle choice for this release.
  PlayerTrackPreferences? get trackPreferences => _trackPreferences;

  /// The prepared session of this page. A failed launch keeps it, so Retry
  /// starts the same torrent again; [close] disposes it.
  String? _ownedSessionId;
  StreamSubscription<PlayerLaunchUpdate>? _launchSubscription;
  Completer<void>? _launchCompleter;
  int _launchAttemptId = 0;

  Future<void> loadPlayback() async {
    final activeLaunch = _launchCompleter;
    if (_launchSubscription != null && activeLaunch != null) {
      developer.log(
        'Ignoring duplicate playback start while another launch is active.',
        name: 'iris.player.cubit',
      );
      await activeLaunch.future;
      return;
    }

    final source = _source;
    _ownedSessionId = source.sessionId.trim().isEmpty ? null : source.sessionId;
    developer.log(
      'Starting playback flow. animeId=${source.animeId} title=${source.animeTitle} source=${source.sourceTitle} sessionId=${source.sessionId} fileIndex=${source.fileIndex}',
      name: 'iris.player.cubit',
    );
    _emitIfOpen(PlayerPreparing(keepsPlayer: _engineOpened));

    if (source.sessionId.trim().isEmpty) {
      developer.log(
        'Playback aborted because sessionId is empty.',
        name: 'iris.player.cubit',
      );
      _emitIfOpen(const PlayerFailure());
      return;
    }

    await _loadSavedState();
    if (isClosed) return;

    final attemptId = ++_launchAttemptId;
    final completer = Completer<void>();
    _launchCompleter = completer;

    try {
      _launchSubscription = _repository
          .startPlayback(
            sessionId: source.sessionId,
            fileIndex: source.fileIndex,
          )
          .listen(
            (update) => unawaited(_handleLaunchUpdate(attemptId, update)),
            onError: (Object error, StackTrace stackTrace) {
              unawaited(_handleLaunchError(attemptId, error, stackTrace));
            },
            onDone: () => unawaited(_handleLaunchDone(attemptId)),
          );
      await completer.future;
    } catch (error, stackTrace) {
      developer.log(
        'Playback failed with unexpected error.',
        name: 'iris.player.cubit',
        error: error,
        stackTrace: stackTrace,
      );
      _emitIfOpen(const PlayerFailure());
      await _finishLaunchAttempt(attemptId);
    }
  }

  void _handleEngineEvent(PlayerEngineEvent event) {
    switch (event) {
      case PlayerEngineProgress(:final position, :final duration, :final flush):
        _requestSkipTimes(duration);
        reportProgress(position, duration, flush: flush);
      case PlayerEnginePlaybackStarted():
        final current = state;
        if (current is PlayerReady && !current.started) {
          _emitIfOpen(current.copyWith(started: true));
        }
      case PlayerEngineCompleted():
        markCompleted();
      case PlayerEngineWatched():
        final current = state;
        if (current is PlayerReady && !current.watched) {
          _emitIfOpen(current.copyWith(watched: true));
        }
      case PlayerEngineTracksChosen(:final preferences):
        saveTrackPreferences(preferences);
    }
  }

  /// Looks up the opening/ending of the current file once its length is
  /// known.
  void _requestSkipTimes(Duration duration) {
    final repository = _skipTimesRepository;
    if (_skipTimesRequested || repository == null) return;
    if (duration <= Duration.zero) return;
    _skipTimesRequested = true;

    final lookup = _skipTimesLookup();
    if (lookup == null) return;
    final (:animeId, :episode) = lookup;
    final source = _source;

    unawaited(() async {
      final segments = await repository.find(
        animeId: animeId,
        episode: episode,
        duration: duration,
      );
      // Ignore a late answer for a file that is no longer playing.
      if (isClosed || !identical(_source, source)) return;
      _engine.useSkipTimes(segments);
    }());
  }

  /// What to look skip times up by, or null when they cannot be: no
  /// lookup, no anime (from its page or the watch history) or no episode
  /// number in the file name.
  ({String animeId, int episode})? _skipTimesLookup() {
    if (_skipTimesRepository == null) return null;
    final source = _source;
    final animeId = source.animeId.isNotEmpty
        ? source.animeId
        : _savedProgress?.animeId ?? '';
    final episode = source.episodeNumber;
    if (animeId.isEmpty || episode == null) return null;
    return (animeId: animeId, episode: episode);
  }

  /// Records the playback position reported by the media player.
  void reportProgress(
    Duration position,
    Duration duration, {
    bool flush = false,
  }) {
    if (_progressRepository == null ||
        _source.torrentKey == null ||
        duration <= Duration.zero) {
      return;
    }
    _lastPosition = position;
    _lastDuration = duration;
    final now = _now();
    // The first report starts the clock instead of saving immediately.
    final lastSavedAt = _lastSavedAt ??= now;
    if (flush || now.difference(lastSavedAt) >= progressSaveInterval) {
      unawaited(_saveProgress());
    }
  }

  /// The file played to its end.
  void markCompleted() {
    final duration = _lastDuration;
    if (duration != null) reportProgress(duration, duration, flush: true);
    final current = state;
    if (current is PlayerReady && current.showResumeNotice) {
      _emitIfOpen(current.copyWith(showResumeNotice: false));
    }
  }

  /// Plays the file from the beginning instead of the saved position.
  /// Chosen before the file has started, the notice stays up so the choice
  /// can still be taken back.
  void restartFromBeginning() => _chooseStart(startOver: true);

  /// Takes back [restartFromBeginning]: plays from the saved position.
  void resumeSavedPosition() => _chooseStart(startOver: false);

  void _chooseStart({required bool startOver}) {
    final current = state;
    if (current is! PlayerReady) return;
    final position = startOver ? Duration.zero : current.startPosition;
    if (position == null) return;
    unawaited(_engine.seek(position));
    _emitIfOpen(
      current.copyWith(
        startsOver: startOver,
        showResumeNotice: current.showResumeNotice && !current.started,
      ),
    );
  }

  void dismissResumeNotice() {
    final current = state;
    if (current is PlayerReady && current.showResumeNotice) {
      _emitIfOpen(current.copyWith(showResumeNotice: false));
    }
  }

  /// Remembers the user's audio/subtitle choice for the whole release.
  void saveTrackPreferences(PlayerTrackPreferences chosen) {
    final repository = _trackPreferencesRepository;
    final torrentKey = _source.torrentKey;
    if (repository == null || torrentKey == null) return;
    final merged = (_trackPreferences ?? const PlayerTrackPreferences())
        .copyWith(audio: chosen.audio, subtitle: chosen.subtitle);
    _trackPreferences = merged;
    unawaited(_persistTrackPreferences(repository, torrentKey, merged));
  }

  /// Switches to another file of the same streamed torrent without
  /// re-adding the torrent. The media player stays, so full screen and the
  /// player's settings carry over to the next file.
  Future<void> playFile(PlayerVideoFile file) async {
    if (_switchingFile || isClosed || _source.files.isEmpty) return;
    _switchingFile = true;
    try {
      await _saveProgress();
      await _cancelActiveLaunch();
      _emitIfOpen(PlayerPreparing(keepsPlayer: _engineOpened));
      // On Windows a paused mpv stops reading the local torrent stream;
      // stopping that stream while mpv still holds the connection blocks
      // the UI thread in a native send(). Release the player's side first.
      await _releaseEngine(_engine.stop);
      if (isClosed) return;
      await _repository.stopPlayback(sessionId: _source.sessionId);
      _source = _source.withFile(file);
      _resetProgressState();
    } finally {
      _switchingFile = false;
    }
    if (!isClosed) await loadPlayback();
  }

  @override
  Future<void> close() async {
    await _cancelActiveLaunch();
    await _releaseEngine(_engine.close);
    await _engineEvents.cancel();
    await _saveProgress();
    await _disposeOwnedSession();
    return super.close();
  }

  Future<void> _releaseEngine(Future<void> Function() release) async {
    try {
      await release().timeout(engineReleaseTimeout);
    } on TimeoutException {
      developer.log(
        'Media player did not release the stream in time; continuing.',
        name: 'iris.player.cubit',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Media player failed to release the stream.',
        name: 'iris.player.cubit',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _loadSavedState() async {
    final torrentKey = _source.torrentKey;
    if (torrentKey == null) return;

    final progressRepository = _progressRepository;
    if (!_progressLoaded && progressRepository != null) {
      _progressLoaded = true;
      try {
        _savedProgress = await progressRepository.find(
          torrentKey: torrentKey,
          fileIndex: _source.fileIndex,
        );
        _startPosition = _savedProgress?.resumePosition;
      } catch (error, stackTrace) {
        _logStorageError('Unable to read watch progress.', error, stackTrace);
      }
    }

    final trackRepository = _trackPreferencesRepository;
    if (!_trackPreferencesLoaded && trackRepository != null) {
      _trackPreferencesLoaded = true;
      try {
        _trackPreferences = await trackRepository.load(torrentKey: torrentKey);
      } catch (error, stackTrace) {
        _logStorageError(
          'Unable to read track preferences.',
          error,
          stackTrace,
        );
      }
    }
  }

  Future<void> _saveProgress() async {
    final repository = _progressRepository;
    final torrentKey = _source.torrentKey;
    final position = _lastPosition;
    final duration = _lastDuration;
    if (repository == null ||
        torrentKey == null ||
        position == null ||
        duration == null) {
      return;
    }
    final saved = _savedProgress;
    // A file opened for a few seconds is not worth a history entry.
    if (saved == null && position < WatchProgress.minResumePosition) return;

    final source = _source;
    // Keep a known anime link when the same file is reopened elsewhere.
    final keepAnime = source.animeId.isEmpty && saved != null;
    final progress = WatchProgress(
      torrentKey: torrentKey,
      fileIndex: source.fileIndex,
      fileName: source.fileName,
      magnet: source.magnet,
      sourceTitle: source.sourceTitle,
      position: position,
      duration: duration,
      updatedAt: _now(),
      animeId: keepAnime ? saved.animeId : source.animeId,
      animeTitle: keepAnime ? saved.animeTitle : source.animeTitle,
    );
    _savedProgress = progress;
    _lastSavedAt = progress.updatedAt;
    try {
      await repository.save(progress);
    } catch (error, stackTrace) {
      _logStorageError('Unable to save watch progress.', error, stackTrace);
    }
  }

  Future<void> _persistTrackPreferences(
    PlayerTrackPreferencesRepository repository,
    String torrentKey,
    PlayerTrackPreferences preferences,
  ) async {
    try {
      await repository.save(torrentKey: torrentKey, preferences: preferences);
    } catch (error, stackTrace) {
      _logStorageError('Unable to save track preferences.', error, stackTrace);
    }
  }

  void _resetProgressState() {
    _skipTimesRequested = false;
    _savedProgress = null;
    _progressLoaded = false;
    _startPosition = null;
    _lastPosition = null;
    _lastDuration = null;
    _lastSavedAt = null;
  }

  void _logStorageError(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'iris.player.cubit',
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<void> _handleLaunchUpdate(
    int attemptId,
    PlayerLaunchUpdate update,
  ) async {
    if (!_isCurrentAttempt(attemptId)) {
      return;
    }

    switch (update) {
      case PlayerLaunchReadyUpdate(:final session):
        _ownedSessionId = session.sessionId;
        developer.log(
          'Playback session prepared successfully. sessionId=${session.sessionId} url=${session.streamUrl}',
          name: 'iris.player.cubit',
        );
        if (isClosed) return;
        // Creates the native player synchronously, so the viewport built
        // for PlayerReady can render it right away.
        final opening = _engine.open(
          session,
          startPosition: _startPosition,
          preferredTracks: _trackPreferences,
        );
        _engineOpened = true;
        if (_skipTimesLookup() != null) _engine.expectSkipTimes();
        _emitIfOpen(
          PlayerReady(
            session,
            startPosition: _startPosition,
            showResumeNotice: _startPosition != null,
          ),
        );
        unawaited(opening);
        await _finishLaunchAttempt(attemptId, cancelSubscription: true);
      case PlayerLaunchFailureUpdate():
        developer.log(
          'Playback launch completed with domain failure.',
          name: 'iris.player.cubit',
        );
        _emitIfOpen(const PlayerFailure());
        await _finishLaunchAttempt(attemptId, cancelSubscription: true);
    }
  }

  Future<void> _handleLaunchDone(int attemptId) async {
    if (!_isCurrentAttempt(attemptId)) {
      return;
    }
    // A ready or failed launch ends the attempt before its stream does, so
    // a stream that ends while still current never said how it went.
    _emitIfOpen(const PlayerFailure());
    await _finishLaunchAttempt(attemptId);
  }

  Future<void> _handleLaunchError(
    int attemptId,
    Object error,
    StackTrace stackTrace,
  ) async {
    if (!_isCurrentAttempt(attemptId)) {
      return;
    }

    developer.log(
      'Playback failed with unexpected error.',
      name: 'iris.player.cubit',
      error: error,
      stackTrace: stackTrace,
    );
    _emitIfOpen(const PlayerFailure());
    await _finishLaunchAttempt(attemptId, cancelSubscription: true);
  }

  Future<void> _cancelActiveLaunch() async {
    _launchAttemptId++;
    final subscription = _launchSubscription;
    _launchSubscription = null;
    final completer = _launchCompleter;
    _launchCompleter = null;
    await subscription?.cancel();
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _finishLaunchAttempt(
    int attemptId, {
    bool cancelSubscription = false,
  }) async {
    if (attemptId != _launchAttemptId) {
      return;
    }

    final subscription = _launchSubscription;
    _launchSubscription = null;
    final completer = _launchCompleter;
    _launchCompleter = null;

    if (cancelSubscription) {
      await subscription?.cancel();
    }

    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  bool _isCurrentAttempt(int attemptId) {
    return !isClosed &&
        attemptId == _launchAttemptId &&
        _launchSubscription != null;
  }

  void _emitIfOpen(PlayerState state) {
    if (!isClosed) {
      emit(state);
    }
  }

  Future<void> _disposeOwnedSession() async {
    final sessionId = _ownedSessionId;
    if (sessionId == null) {
      developer.log(
        'Player cubit has no owned session to dispose.',
        name: 'iris.player.cubit',
      );
      return;
    }

    developer.log(
      'Disposing owned playback session. sessionId=$sessionId',
      name: 'iris.player.cubit',
    );
    _ownedSessionId = null;
    await _repository.disposePlayback(sessionId: sessionId);
  }
}
