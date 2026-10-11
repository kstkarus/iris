import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/presentation/playback/player_buffer_margin.dart';

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
}
