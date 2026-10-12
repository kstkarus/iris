import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/player_chapter_skip_segments.dart';
import 'package:iris/features/player/domain/player_timeline_parts.dart';

const _length = Duration(minutes: 24);

Duration _s(int seconds) => Duration(seconds: seconds);

PlayerChapter _chapter(String title, int seconds) =>
    PlayerChapter(title: title, start: _s(seconds));

PlayerSkipSegment _segment(PlayerSkipKind kind, int start, int end) =>
    PlayerSkipSegment(kind: kind, start: _s(start), end: _s(end));

void main() {
  test('a file with chapters is cut at every one of them', () {
    final parts = timelineParts(
      chapters: [
        _chapter('Opening', 90),
        _chapter('Prologue', 0),
        _chapter('Part A', 180),
        _chapter('', 700),
        _chapter('Ending', 1300),
      ],
      segments: [_segment(PlayerSkipKind.opening, 10, 100)],
      duration: _length,
    );

    expect(parts, [
      PlayerTimelinePart(start: Duration.zero, end: _s(90), title: 'Prologue'),
      PlayerTimelinePart(
        start: _s(90),
        end: _s(180),
        title: 'Opening',
        kind: PlayerSkipKind.opening,
      ),
      PlayerTimelinePart(start: _s(180), end: _s(700), title: 'Part A'),
      PlayerTimelinePart(start: _s(700), end: _s(1300)),
      PlayerTimelinePart(
        start: _s(1300),
        end: _length,
        title: 'Ending',
        kind: PlayerSkipKind.ending,
      ),
    ], reason: 'chapters win over a lookup; an untitled one is still a cut');
  });

  test('chapters past the end or on one time make no empty parts', () {
    final parts = timelineParts(
      chapters: [
        _chapter('Intro', 3),
        _chapter('Main', 60),
        _chapter('Main again', 60),
        _chapter('After', 5000),
      ],
      segments: const [],
      duration: _length,
    );

    expect(parts.map((part) => (part.start, part.end, part.title)), [
      (Duration.zero, _s(60), 'Intro'),
      (_s(60), _length, 'Main again'),
    ]);
  });

  test('without chapters, the lookup and the stretches around it', () {
    final parts = timelineParts(
      chapters: [_chapter('Only one', 0)],
      segments: [
        _segment(PlayerSkipKind.ending, 1320, 1410),
        _segment(PlayerSkipKind.opening, 60, 150),
        _segment(PlayerSkipKind.recap, 140, 170),
      ],
      duration: _length,
    );

    expect(parts, [
      PlayerTimelinePart(start: Duration.zero, end: _s(60)),
      PlayerTimelinePart(
        start: _s(60),
        end: _s(150),
        kind: PlayerSkipKind.opening,
      ),
      PlayerTimelinePart(
        start: _s(150),
        end: _s(170),
        kind: PlayerSkipKind.recap,
      ),
      PlayerTimelinePart(start: _s(170), end: _s(1320)),
      PlayerTimelinePart(
        start: _s(1320),
        end: _s(1410),
        kind: PlayerSkipKind.ending,
      ),
      PlayerTimelinePart(start: _s(1410), end: _length),
    ], reason: 'an overlapping recap starts where the opening ends');
  });

  test('a lookup past the end is cut off at it', () {
    final parts = timelineParts(
      chapters: const [],
      segments: [_segment(PlayerSkipKind.ending, 1400, 1500)],
      duration: _length,
    );

    expect(
      parts.last,
      PlayerTimelinePart(
        start: _s(1400),
        end: _length,
        kind: PlayerSkipKind.ending,
      ),
    );
    expect(parts, hasLength(2));
  });

  test('nothing to cut by, or no length yet, is no cut', () {
    expect(
      timelineParts(chapters: const [], segments: const [], duration: _length),
      isEmpty,
    );
    expect(
      timelineParts(
        chapters: [_chapter('A', 0), _chapter('B', 60)],
        segments: const [],
        duration: Duration.zero,
      ),
      isEmpty,
    );
    expect(
      timelineParts(
        chapters: const [],
        segments: [_segment(PlayerSkipKind.opening, 0, 1440)],
        duration: _length,
      ),
      isEmpty,
      reason: 'one part covering the file has no cut',
    );
  });
}
