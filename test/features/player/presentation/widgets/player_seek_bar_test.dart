import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/presentation/widgets/player_seek_bar.dart';

void main() {
  testWidgets('shows a time only where the pointer would seek to', (
    tester,
  ) async {
    Duration? seeked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: PlayerSeekBar(
                position: const Duration(minutes: 5),
                duration: const Duration(minutes: 20),
                buffered: const Duration(minutes: 6),
                color: Colors.blue,
                onSeek: (position) => seeked = position,
              ),
            ),
          ),
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
}
