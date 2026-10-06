import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/player_chapter_skip_segments.dart';

void main() {
  test('names openings, endings and recaps by chapter title', () {
    final segments = skipSegmentsFromChapters(const [
      PlayerChapter(title: 'Recap', start: Duration.zero),
      PlayerChapter(title: 'Opening', start: Duration(seconds: 60)),
      PlayerChapter(title: 'Part A', start: Duration(seconds: 150)),
      PlayerChapter(title: 'ED', start: Duration(minutes: 22)),
      PlayerChapter(
        title: 'Preview',
        start: Duration(minutes: 23, seconds: 30),
      ),
    ], const Duration(minutes: 24));

    expect(segments, const [
      PlayerSkipSegment(
        kind: PlayerSkipKind.recap,
        start: Duration.zero,
        end: Duration(seconds: 60),
      ),
      PlayerSkipSegment(
        kind: PlayerSkipKind.opening,
        start: Duration(seconds: 60),
        end: Duration(seconds: 150),
      ),
      PlayerSkipSegment(
        kind: PlayerSkipKind.ending,
        start: Duration(minutes: 22),
        end: Duration(minutes: 23, seconds: 30),
      ),
    ]);
  });

  test('recognises common chapter spellings and ignores the rest', () {
    PlayerSkipKind? kindOf(String title) {
      final segments = skipSegmentsFromChapters([
        PlayerChapter(title: title, start: Duration.zero),
      ], const Duration(minutes: 1));
      return segments.firstOrNull?.kind;
    }

    expect(kindOf('OP'), PlayerSkipKind.opening);
    expect(kindOf('OP2'), PlayerSkipKind.opening);
    expect(kindOf('Intro'), PlayerSkipKind.opening);
    expect(kindOf('Opening Credits'), PlayerSkipKind.opening);
    expect(kindOf('Ending'), PlayerSkipKind.ending);
    expect(kindOf('End Credits'), PlayerSkipKind.ending);
    expect(kindOf('Episode'), isNull);
    expect(kindOf('Operation'), isNull);
    expect(kindOf('Chapter 01'), isNull);
  });
}
