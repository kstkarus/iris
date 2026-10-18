import 'dart:async';

import 'package:iris/features/player/presentation/cubit/player_cubit.dart';

class WindowsUpdateRestart {
  WindowsUpdateRestart({
    required Future<void> Function() flushWatchProgress,
    required Future<void> Function() flushDownloads,
  }) : _flushWatchProgress = flushWatchProgress,
       _flushDownloads = flushDownloads;

  final Future<void> Function() _flushWatchProgress;
  final Future<void> Function() _flushDownloads;
  final Set<PlayerCubit> _players = {};

  void trackPlayer(PlayerCubit cubit) {
    _players.add(cubit);
    unawaited(
      cubit.whenClosed.then<void>((_) {
        _players.remove(cubit);
      }),
    );
  }

  Future<void> prepareForRestart() async {
    for (final player in _players.toList()) {
      await player.flushProgressForRestart();
    }
    await _flushWatchProgress();
    await _flushDownloads();
  }
}
