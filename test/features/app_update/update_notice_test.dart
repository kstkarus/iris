import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/app_update/domain/entities/app_version.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:iris/features/app_update/presentation/widgets/update_notice.dart';
import 'package:iris/shared/utils/bayer_mask.dart';
import 'package:iris/shared/widgets/dither_transition.dart';

import '../../helpers/test_app.dart';
import 'app_update_test_doubles.dart';

void main() {
  late List<Uri> opened;
  late bool opens;

  Future<FakeAppUpdateRepository> pumpNotice(WidgetTester tester) async {
    opened = [];
    opens = true;
    final repository = FakeAppUpdateRepository(
      latest: testRelease(3),
      installed: const AppVersion(1, 2, 0),
    );
    final cubit = AppUpdateCubit(repository: repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: UpdateNotice(
              open: (url) async {
                opened.add(url);
                return opens;
              },
              child: const _InsetProbe(),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Version 1.3.0 is out'), findsNothing);
    await tester.runAsync(cubit.check);
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('Download opens the build for this platform', (tester) async {
    await pumpNotice(tester);

    expect(find.text('Version 1.3.0 is out'), findsOneWidget);
    await tester.tap(find.byKey(UpdateNotice.downloadKey));
    await tester.pumpAndSettle();

    expect(opened, [testRelease(3).downloadUrl]);
    expect(find.text('Could not open the download.'), findsNothing);
  });

  testWidgets('a download nothing could open says so', (tester) async {
    await pumpNotice(tester);
    opens = false;

    await tester.tap(find.byKey(UpdateNotice.downloadKey));
    await tester.pumpAndSettle();

    expect(find.text('Could not open the download.'), findsOneWidget);
  });

  testWidgets('the strip takes the status bar inset from the page below', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 72);
    addTearDown(tester.view.resetPadding);
    await pumpNotice(tester);

    expect(_InsetProbe.topOf(tester), 0);
    expect(
      tester.getTopLeft(find.text('Version 1.3.0 is out')).dy,
      greaterThan(24),
    );

    await tester.tap(find.byKey(UpdateNotice.laterKey));
    await tester.pumpAndSettle();

    expect(_InsetProbe.topOf(tester), 24);
  });

  testWidgets('the space opens first, then the strip develops in it', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 72);
    addTearDown(tester.view.resetPadding);
    final cubit = AppUpdateCubit(
      repository: FakeAppUpdateRepository(
        latest: testRelease(3),
        installed: const AppVersion(1, 2, 0),
      ),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const UpdateNotice(child: _InsetProbe()),
          ),
        ),
      ),
    );
    await tester.runAsync(cubit.check);
    await tester.pump();

    int developed() =>
        tester.widget<BayerMasked>(find.byType(BayerMasked)).open;

    // A third in: the space is opening, the strip not painted yet and
    // not to be pressed.
    await tester.pump(DitherTransition.duration * 2 ~/ 3);
    expect(developed(), 0);
    expect(_InsetProbe.topOf(tester), inExclusiveRange(0, 24));
    await tester.tap(find.byKey(UpdateNotice.laterKey), warnIfMissed: false);
    await tester.pump(DitherTransition.duration);
    expect(developed(), greaterThan(0));

    await tester.pumpAndSettle();
    expect(developed(), BayerMask.steps);
    expect(_InsetProbe.topOf(tester), 0);
    expect(cubit.state, isNotNull);
  });

  testWidgets('Later puts the release off', (tester) async {
    final repository = await pumpNotice(tester);

    await tester.tap(find.byKey(UpdateNotice.laterKey));
    await tester.pumpAndSettle();

    expect(find.text('Version 1.3.0 is out'), findsNothing);
    expect(repository.dismissed, const AppVersion(1, 3, 0));
  });
}

/// Shows the top inset the page under the strip is given.
class _InsetProbe extends StatelessWidget {
  const _InsetProbe();

  static double topOf(WidgetTester tester) =>
      MediaQuery.paddingOf(tester.element(find.byType(_InsetProbe))).top;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
