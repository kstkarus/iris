import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/player/data/exceptions/no_playable_video_exception.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';

class PlayerSourceCubit extends Cubit<PlayerSourceState> {
  PlayerSourceCubit({
    required this.magnet,
    required PlayerRepository repository,
  }) : _repository = repository,
       super(const PlayerSourceInitial());

  final String magnet;
  final PlayerRepository _repository;

  PreparedPlayerSource? _preparedSource;
  bool _sessionOwnershipTransferred = false;

  Future<void> loadSource() async {
    developer.log(
      'Starting source preparation flow.',
      name: 'iris.player.source_cubit',
    );
    emit(const PlayerSourceLoading());

    if (magnet.trim().isEmpty) {
      developer.log(
        'Source preparation aborted because magnet is empty.',
        name: 'iris.player.source_cubit',
      );
      emit(const PlayerSourceFailure(PlayerSourceFailureType.unableToPrepare));
      return;
    }

    try {
      final preparedSource = await _repository.prepareSource(magnet: magnet);
      _preparedSource = preparedSource;
      developer.log(
        'Source prepared successfully. sessionId=${preparedSource.sessionId} fileCount=${preparedSource.files.length}',
        name: 'iris.player.source_cubit',
      );
      emit(PlayerSourceReady(preparedSource));
    } on NoPlayableVideoException {
      developer.log(
        'Source preparation failed because no supported video files were found.',
        name: 'iris.player.source_cubit',
      );
      emit(
        const PlayerSourceFailure(PlayerSourceFailureType.unsupportedSource),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Source preparation failed with unexpected error.',
        name: 'iris.player.source_cubit',
        error: error,
        stackTrace: stackTrace,
      );
      emit(const PlayerSourceFailure(PlayerSourceFailureType.unableToPrepare));
    }
  }

  void transferSessionOwnership() {
    _sessionOwnershipTransferred = true;
  }

  @override
  Future<void> close() async {
    final preparedSource = _preparedSource;
    if (!_sessionOwnershipTransferred && preparedSource != null) {
      developer.log(
        'Closing source cubit and disposing sessionId=${preparedSource.sessionId}',
        name: 'iris.player.source_cubit',
      );
      await _repository.disposePlayback(sessionId: preparedSource.sessionId);
    }

    return super.close();
  }
}
