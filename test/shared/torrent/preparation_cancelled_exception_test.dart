import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris/shared/torrent/preparation_cancelled_exception.dart';

void main() {
  group('unlessCancelled', () {
    test('completes with the work when it finishes first', () async {
      final cancelled = Completer<void>();

      expect(await unlessCancelled(Future.value('done'), null), 'done');
      expect(
        await unlessCancelled(Future.value('done'), cancelled.future),
        'done',
      );
    });

    test('fails once cancelled before the work finishes', () async {
      final work = Completer<int>();
      final cancelled = Completer<void>();

      final result = unlessCancelled(work.future, cancelled.future);
      cancelled.complete();

      await expectLater(result, throwsA(isA<PreparationCancelledException>()));
    });
  });
}
