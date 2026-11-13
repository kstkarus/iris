import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/status_views.dart';

import '../../helpers/test_app.dart';

Widget _spinner({bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: const Center(
        child: SizedBox(width: 120, child: BlockSpinner(height: 10)),
      ),
    ),
  );
}

void main() {
  testWidgets('the block spinner holds one frame when motion is reduced', (
    tester,
  ) async {
    await tester.pumpWidget(_spinner(disableAnimations: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(_spinner());
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('a loading view without a label still names what it waits for', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: LoadingView(semanticsLabel: 'Loading files')),
    );

    expect(find.bySemanticsLabel('Loading files'), findsOneWidget);
    expect(find.text('Loading files'), findsNothing);
    semantics.dispose();
  });

  testWidgets('a retry view invokes its action', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      testApp(RetryView(message: 'Failed', onRetry: () => retries++)),
    );
    await tester.tap(find.text('Try Again'));
    expect(retries, 1);
  });

  testWidgets('a paging footer offers retry on failure, then its idle end', (
    tester,
  ) async {
    var retries = 0;
    Widget footer({bool failed = false}) => testApp(
      PagingFooter(
        loadingMore: false,
        failed: failed,
        failedMessage: 'No more',
        onRetry: () => retries++,
        idle: const SizedBox(key: Key('idle')),
      ),
    );

    await tester.pumpWidget(footer(failed: true));
    expect(find.text('No more'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    expect(retries, 1);

    await tester.pumpWidget(footer());
    expect(find.byKey(const Key('idle')), findsOneWidget);
  });
}
