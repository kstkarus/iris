import 'package:iris/features/player/data/models/playback_launch_progress_model.dart';

enum StreamStartupDecisionType { pending, ready, failed }

class StreamStartupDecision {
  const StreamStartupDecision({
    required this.type,
    required this.progress,
    required this.previousStage,
  });

  final StreamStartupDecisionType type;
  final PlaybackLaunchProgressModel progress;
  final PlaybackLaunchStageModel previousStage;

  bool get stageChanged => previousStage != progress.stage;
}

class StreamStartupMonitor {
  StreamStartupMonitor({
    this.readyBufferProgress = 0.5,
    this.progressStallTimeout = const Duration(seconds: 8),
    this.extendedBufferingTimeout = const Duration(seconds: 20),
    this.activityGracePeriod = const Duration(seconds: 4),
    this.absoluteTimeout = const Duration(seconds: 90),
    this.bufferProgressEpsilon = 0.0001,
  });

  final double readyBufferProgress;
  final Duration progressStallTimeout;
  final Duration extendedBufferingTimeout;
  final Duration activityGracePeriod;
  final Duration absoluteTimeout;
  final double bufferProgressEpsilon;

  PlaybackLaunchStageModel _stage = PlaybackLaunchStageModel.buffering;
  Duration _lastProgressAt = Duration.zero;
  Duration _lastActivityAt = Duration.zero;
  Duration? _extendedBufferingStartedAt;
  double _bestBufferProgress = 0;

  StreamStartupDecision evaluate({
    required double bufferProgress,
    required int downloadRateBytesPerSecond,
    required int activePeers,
    required bool isReady,
    required Duration elapsed,
  }) {
    final previousStage = _stage;

    if (bufferProgress > _bestBufferProgress + bufferProgressEpsilon) {
      _bestBufferProgress = bufferProgress;
      _lastProgressAt = elapsed;
      _stage = PlaybackLaunchStageModel.buffering;
      _extendedBufferingStartedAt = null;
    }

    if (downloadRateBytesPerSecond > 0 && activePeers > 0) {
      _lastActivityAt = elapsed;
    }

    if (isReady || bufferProgress >= readyBufferProgress) {
      return StreamStartupDecision(
        type: StreamStartupDecisionType.ready,
        progress: _toProgress(bufferProgress, downloadRateBytesPerSecond),
        previousStage: previousStage,
      );
    }

    if (elapsed >= absoluteTimeout) {
      return StreamStartupDecision(
        type: StreamStartupDecisionType.failed,
        progress: _toProgress(bufferProgress, downloadRateBytesPerSecond),
        previousStage: previousStage,
      );
    }

    final stalledFor = elapsed - _lastProgressAt;
    if (_stage == PlaybackLaunchStageModel.buffering &&
        stalledFor >= progressStallTimeout) {
      if (_hasRecentNetworkActivity(elapsed)) {
        _stage = PlaybackLaunchStageModel.extendedBuffering;
        _extendedBufferingStartedAt ??= elapsed;
      } else {
        return StreamStartupDecision(
          type: StreamStartupDecisionType.failed,
          progress: _toProgress(bufferProgress, downloadRateBytesPerSecond),
          previousStage: previousStage,
        );
      }
    }

    if (_stage == PlaybackLaunchStageModel.extendedBuffering &&
        _extendedBufferingStartedAt != null &&
        elapsed - _extendedBufferingStartedAt! >= extendedBufferingTimeout) {
      return StreamStartupDecision(
        type: StreamStartupDecisionType.failed,
        progress: _toProgress(bufferProgress, downloadRateBytesPerSecond),
        previousStage: previousStage,
      );
    }

    return StreamStartupDecision(
      type: StreamStartupDecisionType.pending,
      progress: _toProgress(bufferProgress, downloadRateBytesPerSecond),
      previousStage: previousStage,
    );
  }

  bool _hasRecentNetworkActivity(Duration elapsed) {
    return elapsed - _lastActivityAt <= activityGracePeriod;
  }

  PlaybackLaunchProgressModel _toProgress(
    double bufferProgress,
    int downloadRateBytesPerSecond,
  ) {
    return PlaybackLaunchProgressModel(
      bufferProgress: bufferProgress.clamp(0.0, 1.0),
      downloadRateBytesPerSecond: downloadRateBytesPerSecond,
      stage: _stage,
    );
  }
}
