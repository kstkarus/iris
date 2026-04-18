import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/presentation/widgets/player_buffer_health_tracker.dart';

void main() {
  test(
    'marks buffer margin as sufficient when the buffered window is large enough',
    () {
      expect(
        resolvePlayerBufferMargin(
          const PlayerPlaybackStats(
            downloadRateBytesPerSecond: 1024,
            appMemoryBytes: null,
            activePeers: 4,
            bufferSeconds: 12,
            bufferPieces: 18,
            readaheadWindow: 40,
          ),
        ),
        PlayerBufferMarginState.insufficient,
      );

      expect(
        resolvePlayerBufferMargin(
          const PlayerPlaybackStats(
            downloadRateBytesPerSecond: 1024,
            appMemoryBytes: null,
            activePeers: 4,
            bufferSeconds: 12,
            bufferPieces: 20,
            readaheadWindow: 32,
          ),
        ),
        PlayerBufferMarginState.sufficient,
      );
    },
  );

  test('does not count a short stall as a rebuffer event', () {
    final clock = _FakeClock();
    final tracker = PlayerRebufferCycleTracker(clock: clock.now);

    tracker.markPlaybackStable();
    clock.advance(const Duration(seconds: 1));

    final detectedCycle = tracker.markBufferingStarted();

    expect(detectedCycle, isFalse);
    expect(tracker.rebufferCount, 0);
  });

  test(
    'detects a rebuffer cycle after three buffered stalls in the same window',
    () {
      final clock = _FakeClock();
      final tracker = PlayerRebufferCycleTracker(clock: clock.now);

      for (var index = 0; index < 3; index++) {
        tracker.markPlaybackStable();
        clock.advance(const Duration(seconds: 3));
        final detectedCycle = tracker.markBufferingStarted();

        if (index < 2) {
          expect(detectedCycle, isFalse);
        } else {
          expect(detectedCycle, isTrue);
        }

        clock.advance(const Duration(seconds: 5));
      }

      expect(tracker.rebufferCount, 3);
      expect(tracker.hasDetectedCycle, isTrue);
    },
  );

  test('resets the rebuffer window after it expires', () {
    final clock = _FakeClock();
    final tracker = PlayerRebufferCycleTracker(clock: clock.now);

    tracker.markPlaybackStable();
    clock.advance(const Duration(seconds: 3));
    tracker.markBufferingStarted();

    clock.advance(const Duration(seconds: 61));
    tracker.markPlaybackStable();
    clock.advance(const Duration(seconds: 3));
    tracker.markBufferingStarted();

    expect(tracker.rebufferCount, 1);
    expect(tracker.hasDetectedCycle, isFalse);
  });
}

class _FakeClock {
  DateTime _current = DateTime(2026, 4, 18, 12);

  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }
}
