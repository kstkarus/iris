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

  Future<void> loadPlayback() async {
    _ownedSessionId = source.sessionId.trim().isEmpty ? null : source.sessionId;
    developer.log(
      'Starting playback flow. animeId=${source.animeId} title=${source.animeTitle} source=${source.sourceTitle} sessionId=${source.sessionId} fileIndex=${source.fileIndex}',
      name: 'iris.player.cubit',
    );
    emit(const PlayerPreparing(progress: PlayerLaunchProgress.initial()));

    if (source.sessionId.trim().isEmpty) {
      developer.log(
        'Playback aborted because sessionId is empty.',
        name: 'iris.player.cubit',
      );
      emit(const PlayerFailure(PlayerLaunchFailure.unableToStart));
      return;
    }

    try {
      await for (final update in _repository.startPlayback(
        sessionId: source.sessionId,
        fileIndex: source.fileIndex,
      )) {
        switch (update) {
          case PlayerLaunchProgressUpdate(:final progress):
            emit(PlayerPreparing(progress: progress));
          case PlayerLaunchReadyUpdate(:final session):
            _ownedSessionId = session.sessionId;
            developer.log(
              'Playback session prepared successfully. sessionId=${session.sessionId} url=${session.streamUrl}',
              name: 'iris.player.cubit',
            );
            emit(PlayerReady(session));
            return;
          case PlayerLaunchFailureUpdate(:final failure):
            developer.log(
              'Playback launch completed with domain failure. failure=$failure',
              name: 'iris.player.cubit',
            );
            await _disposeOwnedSession();
            emit(PlayerFailure(failure));
            return;
        }
      }
      await _disposeOwnedSession();
      emit(const PlayerFailure(PlayerLaunchFailure.unableToStart));
    } catch (error, stackTrace) {
      developer.log(
        'Playback failed with unexpected error.',
        name: 'iris.player.cubit',
        error: error,
        stackTrace: stackTrace,
      );
      await _disposeOwnedSession();
      emit(const PlayerFailure(PlayerLaunchFailure.unableToStart));
    }
  }

  @override
  Future<void> close() async {
    await _disposeOwnedSession();
    return super.close();
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
