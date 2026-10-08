import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';

void main() {
  WatchProgress at(Duration position, {Duration? duration}) => WatchProgress(
    torrentKey: 'torrent',
    fileIndex: 0,
    fileName: 'ep.mkv',
    magnet: 'magnet:?xt=urn:btih:torrent',
    sourceTitle: 'Release',
    position: position,
    duration: duration ?? const Duration(minutes: 24),
    updatedAt: DateTime.utc(2026, 10, 7),
  );

  test('a look at a file is not worth continuing', () {
    expect(at(const Duration(seconds: 40)).isWorthContinuing, isFalse);
    expect(at(const Duration(minutes: 1)).isWorthContinuing, isTrue);
  });

  test('a short file watched to the end is worth continuing', () {
    // The next file is offered from it.
    expect(
      at(
        const Duration(seconds: 50),
        duration: const Duration(seconds: 55),
      ).isWorthContinuing,
      isTrue,
    );
  });
}
