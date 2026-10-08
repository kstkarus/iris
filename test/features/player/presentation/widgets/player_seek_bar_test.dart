import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/presentation/widgets/player_seek_bar.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

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
}

Widget _app(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(child: SizedBox(width: 400, child: child)),
    ),
  );
}

PlayerSeekBar _bar({
  required Duration position,
  required ValueChanged<Duration> onSeek,
}) {
  return PlayerSeekBar(
    position: position,
    duration: const Duration(minutes: 20),
    buffered: const Duration(minutes: 6),
    color: Colors.blue,
    onSeek: onSeek,
  );
}

SemanticsData _sliderData(WidgetTester tester) {
  return tester
      .getSemantics(find.byKey(const Key('player_seek_bar')))
      .getSemanticsData();
}
