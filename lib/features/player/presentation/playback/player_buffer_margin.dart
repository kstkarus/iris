import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/player_buffer_policy.dart';

enum PlayerBufferMarginState { insufficient, sufficient }

PlayerBufferMarginState resolvePlayerBufferMargin(PlayerPlaybackStats stats) {
  final hasEnoughWindow =
      stats.readaheadWindow > 0 &&
      (stats.bufferPieces / stats.readaheadWindow) >=
          playerStartupReadyBufferProgress;
  return hasEnoughWindow
      ? PlayerBufferMarginState.sufficient
      : PlayerBufferMarginState.insufficient;
}
