import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/player_timeline_parts.dart';
import 'package:iris/features/player/presentation/widgets/player_seek_bar.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('shows a time only where the pointer would seek to', (
    tester,
  ) async {
    Duration? seeked;
    await tester.pumpWidget(
      _app(
        PlayerSeekBar(
          position: const Duration(minutes: 5),
          duration: const Duration(minutes: 20),
          buffered: const Duration(minutes: 6),
          color: Colors.blue,
          onSeek: (position) => seeked = position,
        ),
      ),
    );

    final time = find.byKey(const Key('player_seek_bar_time'));
    expect(time, findsNothing, reason: 'the readout beside it has the time');

    final bar = tester.getRect(find.byKey(const Key('player_seek_bar')));
    final middle = Offset(bar.center.dx, bar.bottom - 20);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(middle);
    await tester.pump();
    expect(tester.widget<Text>(time).data, '10:00');

    await tester.tapAt(middle);
    expect(seeked, const Duration(minutes: 10));

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(time, findsNothing);
  });

  testWidgets('screen readers get a slider that moves by a step', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final seeks = <Duration>[];
    await tester.pumpWidget(
      _app(_bar(position: const Duration(minutes: 5), onSeek: seeks.add)),
    );

    final data = _sliderData(tester);
    expect(data.flagsCollection.isSlider, isTrue);
    expect(data.label, 'Playback position');
    expect(data.value, '5:00');
    expect(data.increasedValue, '5:10');
    expect(data.decreasedValue, '4:50');
    expect(
      data.hasAction(SemanticsAction.tap),
      isFalse,
      reason: 'a double tap would seek to the middle of the bar',
    );

    tester.semantics.increase(find.semantics.byLabel('Playback position'));
    tester.semantics.decrease(find.semantics.byLabel('Playback position'));
    expect(seeks, [
      const Duration(minutes: 5, seconds: 10),
      const Duration(minutes: 4, seconds: 50),
    ]);

    semantics.dispose();
  });

  testWidgets('the slider stops at either end of the video', (tester) async {
    final semantics = tester.ensureSemantics();
    final seeks = <Duration>[];
    await tester.pumpWidget(
      _app(
        _bar(
          position: const Duration(minutes: 19, seconds: 55),
          onSeek: seeks.add,
        ),
      ),
    );
    expect(_sliderData(tester).increasedValue, '20:00');
    tester.semantics.increase(find.semantics.byLabel('Playback position'));
    expect(seeks.last, const Duration(minutes: 20));

    await tester.pumpWidget(
      _app(_bar(position: const Duration(seconds: 4), onSeek: seeks.add)),
    );
    expect(_sliderData(tester).decreasedValue, '0:00');
    tester.semantics.decrease(find.semantics.byLabel('Playback position'));
    expect(seeks.last, Duration.zero);

    semantics.dispose();
  });

  testWidgets('the pointer preview is not announced', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(_bar(position: const Duration(minutes: 5), onSeek: (_) {})),
    );

    final bar = tester.getRect(find.byKey(const Key('player_seek_bar')));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(Offset(bar.center.dx, bar.bottom - 20));
    await tester.pump();

    expect(find.text('10:00'), findsOneWidget, reason: 'the preview shows');
    expect(find.bySemanticsLabel('10:00'), findsNothing);
    expect(_sliderData(tester).value, '5:00');

    semantics.dispose();
  });

  testWidgets('names the part under the pointer and for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        _bar(
          position: const Duration(minutes: 1),
          onSeek: (_) {},
          parts: _parts,
        ),
      ),
    );
    expect(_sliderData(tester).value, 'Opening, 1:00');

    final bar = tester.getRect(find.byKey(const Key('player_seek_bar')));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(Offset(bar.center.dx, bar.bottom - 20));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('player_seek_bar_time'))).data,
      'Part A · 10:00',
      reason: 'a chapter goes by its own name',
    );

    await mouse.moveTo(Offset(bar.left + bar.width * 0.02, bar.bottom - 20));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('player_seek_bar_time'))).data,
      '0:24',
      reason: 'a stretch without a name shows the time alone',
    );

    semantics.dispose();
  });

  testWidgets('the time is measured in the font the theme draws it in', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        // A theme font wider than the engine's default.
        DefaultTextStyle(
          style: const TextStyle(letterSpacing: 6),
          child: _bar(
            position: const Duration(minutes: 1),
            onSeek: (_) {},
            parts: _parts,
          ),
        ),
      ),
    );
    final bar = tester.getRect(find.byKey(const Key('player_seek_bar')));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(Offset(bar.center.dx, bar.bottom - 20));
    await tester.pump();

    final label = tester.renderObject<RenderParagraph>(
      find.byKey(const Key('player_seek_bar_time')),
    );
    expect(
      label.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(label.size.width),
      reason: 'the whole time fits its box',
    );
    expect(label.size.height, lessThan(2 * 15), reason: 'one line');
  });

  testWidgets('cuts that arrive run in from the left', (tester) async {
    await tester.pumpWidget(
      _app(_bar(position: Duration.zero, onSeek: (_) {})),
    );
    expect(_cutWidths(tester), isEmpty);

    await tester.pumpWidget(
      _app(_bar(position: Duration.zero, onSeek: (_) {}, parts: _parts)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final early = _cutWidths(tester);
    expect(early, hasLength(3));
    expect(early.first, greaterThan(early.last));
    expect(early.last, lessThan(2));

    await tester.pumpAndSettle();
    expect(_cutWidths(tester), [2, 2, 2]);
  });

  testWidgets('a bar built with its cuts, or without motion, shows them '
      'at once', (tester) async {
    await tester.pumpWidget(
      _app(_bar(position: Duration.zero, onSeek: (_) {}, parts: _parts)),
    );
    expect(_cutWidths(tester), [2, 2, 2]);

    await tester.pumpWidget(
      _app(_bar(position: Duration.zero, onSeek: (_) {}), noMotion: true),
    );
    await tester.pumpWidget(
      _app(
        _bar(position: Duration.zero, onSeek: (_) {}, parts: _parts),
        noMotion: true,
      ),
    );
    expect(_cutWidths(tester), [2, 2, 2]);
  });
}

final _parts = [
  const PlayerTimelinePart(start: Duration.zero, end: Duration(seconds: 30)),
  const PlayerTimelinePart(
    start: Duration(seconds: 30),
    end: Duration(minutes: 2),
    kind: PlayerSkipKind.opening,
  ),
  const PlayerTimelinePart(
    start: Duration(minutes: 2),
    end: Duration(minutes: 18),
    title: 'Part A',
  ),
  const PlayerTimelinePart(
    start: Duration(minutes: 18),
    end: Duration(minutes: 20),
    kind: PlayerSkipKind.ending,
  ),
];

List<double> _cutWidths(WidgetTester tester) {
  final clip = tester.widget<ClipPath>(
    find.byKey(const Key('player_seek_bar_track')),
  );
  return [for (final cut in (clip.clipper! as SeekBarCuts).cutsAt()) cut.width];
}

Widget _app(Widget child, {bool noMotion = false}) {
  final bar = Scaffold(
    body: Center(child: SizedBox(width: 400, child: child)),
  );
  return testApp(
    noMotion
        ? Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: bar,
            ),
          )
        : bar,
  );
}

PlayerSeekBar _bar({
  required Duration position,
  required ValueChanged<Duration> onSeek,
  List<PlayerTimelinePart> parts = const [],
}) {
  return PlayerSeekBar(
    position: position,
    duration: const Duration(minutes: 20),
    buffered: const Duration(minutes: 6),
    color: Colors.blue,
    onSeek: onSeek,
    parts: parts,
  );
}

SemanticsData _sliderData(WidgetTester tester) {
  return tester
      .getSemantics(find.byKey(const Key('player_seek_bar')))
      .getSemanticsData();
}
