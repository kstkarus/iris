import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/app_update/domain/entities/app_version.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_cubit.dart';

import 'app_update_test_doubles.dart';

void main() {
  Future<AppUpdateCubit> checked(FakeAppUpdateRepository repository) async {
    final cubit = AppUpdateCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.check();
    return cubit;
  }

  test('offers a newer release', () async {
    final cubit = await checked(
      FakeAppUpdateRepository(
        latest: testRelease(3),
        installed: const AppVersion(1, 2, 0),
      ),
    );

    expect(cubit.state, testRelease(3));
  });

  test('offers nothing for the running version or an older one', () async {
    for (final installed in const [AppVersion(1, 3, 0), AppVersion(1, 4, 0)]) {
      final cubit = await checked(
        FakeAppUpdateRepository(latest: testRelease(3), installed: installed),
      );
      expect(cubit.state, isNull);
    }
  });

  test('a release put off is not offered again; a newer one is', () async {
    final repository = FakeAppUpdateRepository(
      latest: testRelease(3),
      installed: const AppVersion(1, 2, 0),
    );
    final cubit = await checked(repository);

    await cubit.dismiss();
    expect(cubit.state, isNull);
    expect(repository.dismissed, const AppVersion(1, 3, 0));

    await cubit.check();
    expect(cubit.state, isNull);

    repository.latest = testRelease(4);
    await cubit.check();
    expect(cubit.state, testRelease(4));
  });

  test('a failed check offers nothing', () async {
    final cubit = await checked(
      FakeAppUpdateRepository(
        latest: testRelease(3),
        installed: const AppVersion(1, 2, 0),
      )..failing = true,
    );

    expect(cubit.state, isNull);
  });
}
