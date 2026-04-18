enum PlayerLaunchStage { preparing, waitingForBuffer }

class PlayerLaunchProgress {
  const PlayerLaunchProgress({
    required this.bufferProgress,
    required this.downloadRateBytesPerSecond,
    required this.stage,
  });

  const PlayerLaunchProgress.initial()
    : bufferProgress = 0,
      downloadRateBytesPerSecond = 0,
      stage = PlayerLaunchStage.preparing;

  final double bufferProgress;
  final int downloadRateBytesPerSecond;
  final PlayerLaunchStage stage;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerLaunchProgress &&
        other.bufferProgress == bufferProgress &&
        other.downloadRateBytesPerSecond == downloadRateBytesPerSecond &&
        other.stage == stage;
  }

  @override
  int get hashCode =>
      Object.hash(bufferProgress, downloadRateBytesPerSecond, stage);
}
