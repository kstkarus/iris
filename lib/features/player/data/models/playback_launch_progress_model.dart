enum PlaybackLaunchStageModel { buffering, extendedBuffering }

class PlaybackLaunchProgressModel {
  const PlaybackLaunchProgressModel({
    required this.bufferProgress,
    required this.downloadRateBytesPerSecond,
    required this.stage,
  });

  final double bufferProgress;
  final int downloadRateBytesPerSecond;
  final PlaybackLaunchStageModel stage;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlaybackLaunchProgressModel &&
        other.bufferProgress == bufferProgress &&
        other.downloadRateBytesPerSecond == downloadRateBytesPerSecond &&
        other.stage == stage;
  }

  @override
  int get hashCode =>
      Object.hash(bufferProgress, downloadRateBytesPerSecond, stage);
}
