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

class PlayerRebufferCycleTracker {
  PlayerRebufferCycleTracker({
    DateTime Function()? clock,
    this.stablePlaybackThreshold = playerRebufferStablePlaybackThreshold,
    this.window = playerRebufferWindow,
    this.cycleThreshold = playerRebufferCycleThreshold,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration stablePlaybackThreshold;
  final Duration window;
  final int cycleThreshold;

  DateTime? _stablePlaybackStartedAt;
  DateTime? _windowStartedAt;
  int _rebufferCount = 0;
  bool _hasDetectedCycle = false;

  int get rebufferCount => _rebufferCount;
  bool get hasDetectedCycle => _hasDetectedCycle;

  void reset() {
    _stablePlaybackStartedAt = null;
    _windowStartedAt = null;
    _rebufferCount = 0;
    _hasDetectedCycle = false;
  }

  void markPlaybackStable() {
    _stablePlaybackStartedAt ??= _clock();
  }

  void clearStablePlayback() {
    _stablePlaybackStartedAt = null;
  }

  bool markBufferingStarted() {
    final now = _clock();
    final stablePlaybackStartedAt = _stablePlaybackStartedAt;
    _stablePlaybackStartedAt = null;

    if (stablePlaybackStartedAt == null ||
        now.difference(stablePlaybackStartedAt) < stablePlaybackThreshold) {
      return false;
    }

    final windowStartedAt = _windowStartedAt;
    if (windowStartedAt == null || now.difference(windowStartedAt) > window) {
      _windowStartedAt = now;
      _rebufferCount = 1;
      _hasDetectedCycle = false;
      return false;
    }

    _rebufferCount += 1;
    if (_rebufferCount >= cycleThreshold) {
      _hasDetectedCycle = true;
      return true;
    }

    return false;
  }
}
