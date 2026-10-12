import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/app_update/domain/entities/app_version.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:iris/features/app_update/presentation/widgets/update_notice.dart';

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

  testWidgets('Later puts the release off', (tester) async {
    final repository = await pumpNotice(tester);

    await tester.tap(find.byKey(UpdateNotice.laterKey));
    await tester.pumpAndSettle();

    expect(find.text('Version 1.3.0 is out'), findsNothing);
    expect(repository.dismissed, const AppVersion(1, 3, 0));
  });
}
