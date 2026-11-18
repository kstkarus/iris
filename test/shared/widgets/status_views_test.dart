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

  testWidgets('a paging footer eases between loading, failure, and idle', (
    tester,
  ) async {
    Widget footer({
      bool loadingMore = false,
      bool failed = false,
      bool disableAnimations = false,
    }) => testApp(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: PagingFooter(
          loadingMore: loadingMore,
          failed: failed,
          failedMessage: 'Failed to load',
          onRetry: () {},
          idle: const SizedBox(key: Key('idle')),
        ),
      ),
    );

    await tester.pumpWidget(footer(loadingMore: true));
    await tester.pumpWidget(footer(failed: true));
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Failed to load'), findsOneWidget);

    await tester.pumpWidget(footer());
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('idle')), findsOneWidget);

    await tester.pumpWidget(footer(loadingMore: true, disableAnimations: true));
    await tester.pumpWidget(footer(failed: true, disableAnimations: true));
    await tester.pump();
    expect(find.text('Failed to load'), findsOneWidget);
  });
}
