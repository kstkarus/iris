import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:iris/features/player/presentation/playback/player_video_sized.dart';

void main() {
  test('a player that already has a size is ready at once', () async {
    final sized = playerVideoSized(
      state: () => const PlayerState(width: 1920, height: 1080),
      widths: const Stream.empty(),
    );

    await expectLater(sized, completes);
  });

  test('a cleared size waits for the next file to be sized', () async {
    var state = const PlayerState();
    final widths = StreamController<int?>();
    var done = false;
    unawaited(
      playerVideoSized(
        state: () => state,
        widths: widths.stream,
      ).then((_) => done = true),
    );

    widths.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);

    state = const PlayerState(width: 1280, height: 720);
    widths.add(1280);
    await Future<void>.delayed(Duration.zero);
    expect(done, isTrue);
    await widths.close();
  });
}
