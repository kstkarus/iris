import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_launch_failure.dart';
import 'package:iris/features/player/domain/entities/player_launch_progress.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';

class PlayerCubit extends Cubit<PlayerState> {
  PlayerCubit({required this.source, required PlayerRepository repository})
    : _repository = repository,
      super(const PlayerInitial());

  final AnimePlayerSource source;
  final PlayerRepository _repository;

  String? _ownedSessionId;
  StreamSubscription<PlayerLaunchUpdate>? _launchSubscription;
  Completer<void>? _launchCompleter;
  int _launchAttemptId = 0;
  bool _receivedTerminalLaunchUpdate = false;

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

    _ownedSessionId = source.sessionId.trim().isEmpty ? null : source.sessionId;
    developer.log(
      'Starting playback flow. animeId=${source.animeId} title=${source.animeTitle} source=${source.sourceTitle} sessionId=${source.sessionId} fileIndex=${source.fileIndex}',
      name: 'iris.player.cubit',
    );
    _emitIfOpen(
      const PlayerPreparing(progress: PlayerLaunchProgress.initial()),
    );

    if (source.sessionId.trim().isEmpty) {
      developer.log(
        'Playback aborted because sessionId is empty.',
        name: 'iris.player.cubit',
      );
      _emitIfOpen(const PlayerFailure(PlayerLaunchFailure.unableToStart));
      return;
    }

    final attemptId = ++_launchAttemptId;
    _receivedTerminalLaunchUpdate = false;
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
            cancelOnError: false,
          );
      await completer.future;
    } catch (error, stackTrace) {
      developer.log(
        'Playback failed with unexpected error.',
        name: 'iris.player.cubit',
        error: error,
        stackTrace: stackTrace,
      );
      await _disposeOwnedSession();
      _emitIfOpen(const PlayerFailure(PlayerLaunchFailure.unableToStart));
      await _finishLaunchAttempt(attemptId);
    }
  }

  @override
  Future<void> close() async {
    await _cancelActiveLaunch();
    await _disposeOwnedSession();
    return super.close();
  }

  Future<void> _handleLaunchUpdate(
    int attemptId,
    PlayerLaunchUpdate update,
  ) async {
    if (!_isCurrentAttempt(attemptId)) {
      return;
    }

    switch (update) {
      case PlayerLaunchProgressUpdate(:final progress):
        _emitIfOpen(PlayerPreparing(progress: progress));
      case PlayerLaunchReadyUpdate(:final session):
        _receivedTerminalLaunchUpdate = true;
        _ownedSessionId = session.sessionId;
        developer.log(
          'Playback session prepared successfully. sessionId=${session.sessionId} url=${session.streamUrl}',
          name: 'iris.player.cubit',
        );
        _emitIfOpen(PlayerReady(session));
        await _finishLaunchAttempt(attemptId, cancelSubscription: true);
      case PlayerLaunchFailureUpdate(:final failure):
        _receivedTerminalLaunchUpdate = true;
        developer.log(
          'Playback launch completed with domain failure. failure=$failure',
          name: 'iris.player.cubit',
        );
        await _disposeOwnedSession();
        if (!_isCurrentAttempt(attemptId)) {
          return;
        }
        _emitIfOpen(PlayerFailure(failure));
        await _finishLaunchAttempt(attemptId, cancelSubscription: true);
    }
  }

  Future<void> _handleLaunchDone(int attemptId) async {
    if (!_isCurrentAttempt(attemptId)) {
      return;
    }
    if (!_receivedTerminalLaunchUpdate) {
      await _disposeOwnedSession();
      if (_isCurrentAttempt(attemptId)) {
        _emitIfOpen(const PlayerFailure(PlayerLaunchFailure.unableToStart));
      }
    }
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
    await _disposeOwnedSession();
    if (_isCurrentAttempt(attemptId)) {
      _emitIfOpen(const PlayerFailure(PlayerLaunchFailure.unableToStart));
    }
    await _finishLaunchAttempt(attemptId, cancelSubscription: true);
  }

  Future<void> _cancelActiveLaunch() async {
    _launchAttemptId++;
    final subscription = _launchSubscription;
    _launchSubscription = null;
    _receivedTerminalLaunchUpdate = false;
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
    _receivedTerminalLaunchUpdate = false;
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
