import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/data/adapters/stream_startup_monitor.dart';
import 'package:iris/features/player/data/models/playback_launch_progress_model.dart';

void main() {
  test('reports ready when buffer progress reaches startup threshold', () {
    final monitor = StreamStartupMonitor();

    final decision = monitor.evaluate(
      bufferProgress: 0.5,
      downloadRateBytesPerSecond: 2048,
      activePeers: 4,
      isReady: false,
      elapsed: const Duration(seconds: 3),
    );

    expect(decision.type, StreamStartupDecisionType.ready);
    expect(
      decision.progress,
      const PlaybackLaunchProgressModel(
        bufferProgress: 0.5,
        downloadRateBytesPerSecond: 2048,
        stage: PlaybackLaunchStageModel.buffering,
      ),
    );
  });

  test('switches to extended buffering when progress stalls but peers stay active', () {
    final monitor = StreamStartupMonitor();

    monitor.evaluate(
      bufferProgress: 0.125,
      downloadRateBytesPerSecond: 8192,
      activePeers: 6,
      isReady: false,
      elapsed: const Duration(seconds: 1),
    );

    final decision = monitor.evaluate(
      bufferProgress: 0.125,
      downloadRateBytesPerSecond: 4096,
      activePeers: 5,
      isReady: false,
      elapsed: const Duration(seconds: 9),
    );

    expect(decision.type, StreamStartupDecisionType.pending);
    expect(decision.stageChanged, isTrue);
    expect(
      decision.progress,
      const PlaybackLaunchProgressModel(
        bufferProgress: 0.125,
        downloadRateBytesPerSecond: 4096,
        stage: PlaybackLaunchStageModel.extendedBuffering,
      ),
    );
  });

  test('fails after extended buffering window expires without new progress', () {
    final monitor = StreamStartupMonitor();

    monitor.evaluate(
      bufferProgress: 0.125,
      downloadRateBytesPerSecond: 8192,
      activePeers: 6,
      isReady: false,
      elapsed: const Duration(seconds: 1),
    );
    monitor.evaluate(
      bufferProgress: 0.125,
      downloadRateBytesPerSecond: 4096,
      activePeers: 5,
      isReady: false,
      elapsed: const Duration(seconds: 9),
    );

    final decision = monitor.evaluate(
      bufferProgress: 0.125,
      downloadRateBytesPerSecond: 2048,
      activePeers: 4,
      isReady: false,
      elapsed: const Duration(seconds: 29),
    );

    expect(decision.type, StreamStartupDecisionType.failed);
    expect(decision.progress.stage, PlaybackLaunchStageModel.extendedBuffering);
  });

  test('fails earlier when progress stalls and network activity disappears', () {
    final monitor = StreamStartupMonitor();

    final decision = monitor.evaluate(
      bufferProgress: 0.0,
      downloadRateBytesPerSecond: 0,
      activePeers: 0,
      isReady: false,
      elapsed: const Duration(seconds: 8),
    );

    expect(decision.type, StreamStartupDecisionType.failed);
    expect(decision.progress.stage, PlaybackLaunchStageModel.buffering);
  });
}
