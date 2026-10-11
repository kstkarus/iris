import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/presentation/widgets/player_wait_indicator.dart';

import '../../../../helpers/test_app.dart';

void main() {
  const color = Color(0xFF00FF00);
  const track = Color(0x3DFFFFFF);

  Widget app(Widget child, {bool disableAnimations = false}) {
    return testApp(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Center(child: child),
      ),
    );
  }

  testWidgets('the runner is a square the size of the play glyph', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(const BlockRunner(color: color, trackColor: track)),
    );

    expect(tester.getSize(find.byType(BlockRunner)), const Size.square(42));
  });

  testWidgets('the runner steps around the square and stops when motion '
      'is reduced', (tester) async {
    await tester.pumpWidget(
      app(const BlockRunner(color: color, trackColor: track)),
    );
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(BlockRunner.step * 3);

    await tester.pumpWidget(
      app(
        const BlockRunner(color: color, trackColor: track),
        disableAnimations: true,
      ),
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the wait label adds the torrent numbers once the wait drags '
      'on', (tester) async {
    final stats = ValueNotifier<PlayerPlaybackStats?>(_stats(rate: 2516582));
    addTearDown(stats.dispose);

    await tester.pumpWidget(
      app(PlayerWaitLabel(label: 'Buffering', stats: stats, style: null)),
    );
    expect(find.text('Buffering'), findsOneWidget);
    expect(find.byKey(const Key('player_wait_stats')), findsNothing);

    await tester.pump(PlayerWaitLabel.statsDelay);
    expect(find.text('2.4 MB/s · 12 peers'), findsOneWidget);

    stats.value = _stats(rate: 1024, peers: 1);
    await tester.pump();
    expect(find.text('1 KB/s · 1 peer'), findsOneWidget);
  });

  testWidgets('the wait label says nothing about a source that moves no '
      'data', (tester) async {
    // A local file reports zeros: "0 peers" would misdescribe it.
    final stats = ValueNotifier<PlayerPlaybackStats?>(
      _stats(rate: 0, peers: 0),
    );
    addTearDown(stats.dispose);

    await tester.pumpWidget(
      app(PlayerWaitLabel(label: 'Buffering', stats: stats, style: null)),
    );
    await tester.pump(PlayerWaitLabel.statsDelay);

    expect(find.byKey(const Key('player_wait_stats')), findsNothing);
  });

  testWidgets('the wait label says a torrent that moves nothing has no peers '
      'yet', (tester) async {
    final stats = ValueNotifier<PlayerPlaybackStats?>(
      _stats(rate: 0, peers: 0, isTorrent: true),
    );
    addTearDown(stats.dispose);

    await tester.pumpWidget(
      app(PlayerWaitLabel(label: 'Buffering', stats: stats, style: null)),
    );
    await tester.pump(PlayerWaitLabel.statsDelay);

    expect(find.text('No peers yet'), findsOneWidget);
  });
}

PlayerPlaybackStats _stats({
  required int rate,
  int peers = 12,
  bool isTorrent = false,
}) {
  return PlayerPlaybackStats(
    downloadRateBytesPerSecond: rate,
    appMemoryBytes: null,
    activePeers: peers,
    bufferSeconds: 0,
    bufferPieces: 0,
    readaheadWindow: 0,
    isTorrent: isTorrent,
  );
}
