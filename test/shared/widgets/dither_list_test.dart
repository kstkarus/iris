import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/dither_list.dart';
import 'package:iris/shared/widgets/dither_transition.dart';

void main() {
  Widget list(
    List<String> items, {
    bool noMotion = false,
    bool framed = false,
    int columns = 1,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: noMotion),
      child: Scaffold(
        body: DitherList<String>(
          items: items,
          header: framed
              ? const SizedBox(height: 20, child: Text('header'))
              : null,
          footer: framed
              ? const SizedBox(height: 30, child: Text('footer'))
              : null,
          keyOf: (item) => item,
          crossAxisCount: columns,
          columnSpacing: 16,
          rowSpacing: columns == 1 ? 0 : 24,
          itemBuilder: (context, item) =>
              SizedBox(height: 40, child: Text(item)),
        ),
      ),
    ),
  );

  double heightOf(WidgetTester tester, String item) => tester
      .getSize(
        find
            .ancestor(of: find.text(item), matching: find.byType(ClipRect))
            .first,
      )
      .height;

  testWidgets('rows there at first simply show', (tester) async {
    await tester.pumpWidget(list(['a', 'b']));

    expect(find.byType(BayerMasked), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
    'header and footer share the scroll and stay outside row animations',
    (tester) async {
      await tester.pumpWidget(list(['a'], framed: true));
      expect(find.byType(Scrollable), findsOneWidget);
      expect(tester.getTopLeft(find.text('a')).dy, 20);
      await tester.pumpWidget(list(['b', 'a'], framed: true));
      await tester.pump(DitherTransition.duration ~/ 2);
      for (final text in ['header', 'footer', 'a']) {
        expect(
          find.ancestor(
            of: find.text(text),
            matching: find.byType(BayerMasked),
          ),
          findsNothing,
        );
      }
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('a')).dy, 60);
      expect(tester.getTopLeft(find.text('footer')).dy, 100);
      await tester.pumpWidget(list(['a'], framed: true));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('footer')).dy, 60);
    },
  );

  testWidgets('a new row opens its space, then develops', (tester) async {
    await tester.pumpWidget(list(['a']));
    await tester.pumpWidget(list(['b', 'a']));

    await tester.pump(DitherTransition.duration ~/ 2);
    expect(heightOf(tester, 'b'), inExclusiveRange(0, 40));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.text('b')).height, greaterThan(0));
    expect(tester.getTopLeft(find.text('a')).dy, 40);
  });

  testWidgets('a row that came in stays in when another comes above it', (
    tester,
  ) async {
    await tester.pumpWidget(list(['a']));
    await tester.pumpWidget(list(['x', 'a']));
    await tester.pumpAndSettle();

    await tester.pumpWidget(list(['y', 'x', 'a']));
    await tester.pump(DitherTransition.duration ~/ 2);

    expect(
      find.ancestor(of: find.text('x'), matching: find.byType(BayerMasked)),
      findsNothing,
      reason: 'x does not open again',
    );
    expect(tester.getSize(find.text('x')).height, 40);
  });

  testWidgets('a removed row dissolves, then gives its height back', (
    tester,
  ) async {
    await tester.pumpWidget(list(['a', 'b']));
    await tester.pumpWidget(list(['b']));

    await tester.pump(DitherTransition.duration ~/ 2);
    expect(find.text('a'), findsOneWidget, reason: 'still dissolving');
    expect(heightOf(tester, 'a'), 40);
    await tester.pump(DitherTransition.duration);
    expect(heightOf(tester, 'a'), lessThan(40));

    await tester.pumpAndSettle();
    expect(find.text('a'), findsNothing);
    expect(tester.getTopLeft(find.text('b')).dy, 0);
  });

  testWidgets('a row put back while leaving stays', (tester) async {
    await tester.pumpWidget(list(['a', 'b']));
    await tester.pumpWidget(list(['b']));
    await tester.pump(DitherTransition.duration ~/ 2);

    await tester.pumpWidget(list(['a', 'b']));
    await tester.pumpAndSettle();

    expect(find.text('a'), findsOneWidget);
    expect(tester.getTopLeft(find.text('b')).dy, 40);
  });

  testWidgets('a row removed while out of sight does not come back', (
    tester,
  ) async {
    final items = [for (var n = 0; n < 60; n++) 'row $n'];
    await tester.pumpWidget(list(items));
    expect(find.text('row 40'), findsNothing, reason: 'not built yet');

    await tester.pumpWidget(list([...items]..remove('row 40')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('row 41'), 200);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable), const Offset(0, 200));
    await tester.pumpAndSettle();

    expect(find.text('row 40', skipOffstage: false), findsNothing);
    expect(
      tester.getTopLeft(find.text('row 41')).dy -
          tester.getTopLeft(find.text('row 39')).dy,
      40,
    );
  });

  testWidgets('without motion rows come and go at once', (tester) async {
    await tester.pumpWidget(list(['a'], noMotion: true));
    await tester.pumpWidget(list(['b', 'a'], noMotion: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.getTopLeft(find.text('a')).dy, 40);

    await tester.pumpWidget(list(['a'], noMotion: true));
    await tester.pump();
    expect(find.text('b'), findsNothing);
  });

  testWidgets('grid animates only inserted and removed entries', (
    tester,
  ) async {
    await tester.pumpWidget(list(['a', 'b'], columns: 2));
    expect(find.byType(BayerMasked), findsNothing);

    await tester.pumpWidget(list(['a', 'b', 'c'], columns: 2));
    await tester.pump(DitherTransition.duration ~/ 2);
    expect(
      find.ancestor(of: find.text('c'), matching: find.byType(BayerMasked)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: find.text('a'), matching: find.byType(BayerMasked)),
      findsNothing,
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(list(['b', 'c'], columns: 2));
    await tester.pump(DitherTransition.duration ~/ 2);
    expect(
      find.ancestor(of: find.text('a'), matching: find.byType(BayerMasked)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: find.text('b'), matching: find.byType(BayerMasked)),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(find.text('a'), findsNothing);
  });

  testWidgets('grid content updates do not replay entry animation', (
    tester,
  ) async {
    Widget progressList(int progress, {int columns = 2}) => MaterialApp(
      home: Scaffold(
        body: DitherList<({String id, int progress})>(
          items: [(id: 'a', progress: progress), (id: 'b', progress: progress)],
          keyOf: (item) => item.id,
          crossAxisCount: columns,
          itemBuilder: (context, item) => Text('${item.id}:${item.progress}'),
        ),
      ),
    );

    await tester.pumpWidget(progressList(10));
    await tester.pumpWidget(progressList(20));
    expect(find.text('a:20'), findsOneWidget);
    expect(find.byType(BayerMasked), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(progressList(20, columns: 1));
    expect(find.text('a:20'), findsOneWidget);
    expect(find.byType(BayerMasked), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('grid respects reduced motion for add and remove', (
    tester,
  ) async {
    await tester.pumpWidget(list(['a', 'b'], columns: 2, noMotion: true));
    await tester.pumpWidget(list(['a', 'b', 'c'], columns: 2, noMotion: true));
    await tester.pump();
    expect(find.byType(BayerMasked), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(list(['b', 'c'], columns: 2, noMotion: true));
    await tester.pump();
    expect(find.text('a'), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
