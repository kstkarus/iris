import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/utils/serial_queue.dart';

void main() {
  test('runs operations one after another', () async {
    final queue = SerialQueue();
    final first = Completer<void>();
    final log = <String>[];

    final a = queue.run(() async {
      log.add('a start');
      await first.future;
      log.add('a end');
      return 1;
    });
    final b = queue.run(() async {
      log.add('b');
      return 2;
    });
    await pumpEventQueue();
    expect(log, ['a start']);

    first.complete();
    expect(await a, 1);
    expect(await b, 2);
    expect(log, ['a start', 'a end', 'b']);
  });

  test('a failed operation fails only its own future', () async {
    final queue = SerialQueue();

    final failed = queue.run<void>(() async => throw StateError('boom'));
    final next = queue.run(() async => 'next');

    await expectLater(failed, throwsStateError);
    expect(await next, 'next');
    await queue.idle;
  });

  test('idle waits for the queued operations', () async {
    final queue = SerialQueue();
    final gate = Completer<void>();
    var done = false;
    unawaited(
      queue.run(() async {
        await gate.future;
        done = true;
      }),
    );

    final idle = queue.idle;
    gate.complete();
    await idle;

    expect(done, isTrue);
  });
}
