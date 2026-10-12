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

  group('with the Shikimori list', () {
    const series = [
      PlayerVideoFile(index: 0, name: 'ep-01.mkv', size: 1, extension: 'mkv'),
      PlayerVideoFile(index: 1, name: 'ep-02.mkv', size: 1, extension: 'mkv'),
      PlayerVideoFile(index: 2, name: 'ep-03.mkv', size: 1, extension: 'mkv'),
      PlayerVideoFile(index: 3, name: 'ep-04.mkv', size: 1, extension: 'mkv'),
    ];
    const finished = Duration(minutes: 24);

    test('plays on after what the list counts', () {
      final target = continueTarget(series, const {}, listed: {0, 1});

      expect(target?.file.index, 2);
      expect(target?.isNext, isTrue);
    });

    test('goes with whichever got further', () {
      expect(
        continueTarget(
          series,
          {0: _progress(0, position: finished, day: 1)},
          listed: {0, 1, 2},
        )?.file.index,
        3,
      );
      expect(
        continueTarget(
          series,
          {2: _progress(2, position: finished, day: 1)},
          listed: {0},
        )?.file.index,
        3,
      );
    });

    test('a file stopped partway here is gone on with', () {
      final target = continueTarget(
        series,
        {1: _progress(1, position: const Duration(minutes: 5), day: 1)},
        listed: {0, 1, 2},
      );

      expect(target?.file.index, 1);
      expect(target?.isNext, isFalse);
    });

    test('a list that has it all leaves a rewatch where it is', () {
      expect(
        continueTarget(
          series,
          {0: _progress(0, position: finished, day: 1)},
          listed: {0, 1, 2, 3},
        )?.file.index,
        1,
      );
      expect(continueTarget(series, const {}, listed: {0, 1, 2, 3}), isNull);
    });
  });
}
