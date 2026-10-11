import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/player_continue_target.dart';

const _files = [
  PlayerVideoFile(index: 4, name: 'ep-01.mkv', size: 1, extension: 'mkv'),
  PlayerVideoFile(index: 7, name: 'ep-02.mkv', size: 1, extension: 'mkv'),
];

WatchProgress _progress(
  int fileIndex, {
  required Duration position,
  required int day,
}) => WatchProgress(
  torrentKey: 'key',
  fileIndex: fileIndex,
  fileName: 'file.mkv',
  magnet: 'magnet:?xt=urn:btih:key',
  sourceTitle: 'Release',
  position: position,
  duration: const Duration(minutes: 24),
  updatedAt: DateTime(2026, 1, day),
);

void main() {
  test('gives nothing without progress', () {
    expect(continueTarget(_files, const {}), isNull);
  });

  test('continues the file watched last', () {
    final target = continueTarget(_files, {
      7: _progress(7, position: const Duration(minutes: 5), day: 1),
      4: _progress(4, position: const Duration(minutes: 3), day: 2),
    });

    expect(target?.file.index, 4);
    expect(target?.isNext, isFalse);
  });

  test('moves on past a finished file, but not past the last', () {
    const finished = Duration(minutes: 24);

    final next = continueTarget(_files, {
      4: _progress(4, position: finished, day: 1),
    });
    expect(next?.file.index, 7);
    expect(next?.isNext, isTrue);

    expect(
      continueTarget(_files, {7: _progress(7, position: finished, day: 1)}),
      isNull,
    );
  });
}
