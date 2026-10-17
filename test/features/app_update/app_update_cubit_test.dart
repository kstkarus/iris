import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_update_failure.dart';
import 'package:iris/features/app_update/domain/entities/app_version.dart';
import 'package:iris/features/app_update/domain/repositories/app_update_download_repository.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_state.dart';

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

    expect(cubit.state.release, testRelease(3));
  });

  test('offers nothing for the running version or an older one', () async {
    for (final installed in const [AppVersion(1, 3, 0), AppVersion(1, 4, 0)]) {
      final cubit = await checked(
        FakeAppUpdateRepository(latest: testRelease(3), installed: installed),
      );
      expect(cubit.state.release, isNull);
    }
  });

  test('a release put off is not offered again; a newer one is', () async {
    final repository = FakeAppUpdateRepository(
      latest: testRelease(3),
      installed: const AppVersion(1, 2, 0),
    );
    final cubit = await checked(repository);

    await cubit.dismiss();
    expect(cubit.state.release, isNull);
    expect(repository.dismissed, const AppVersion(1, 3, 0));

    await cubit.check();
    expect(cubit.state.release, isNull);

    repository.latest = testRelease(4);
    await cubit.check();
    expect(cubit.state.release, testRelease(4));
  });

  test('a failed check offers nothing', () async {
    final cubit = await checked(
      FakeAppUpdateRepository(
        latest: testRelease(3),
        installed: const AppVersion(1, 2, 0),
      )..failing = true,
    );

    expect(cubit.state.release, isNull);
  });

  group('Android download and installation', () {
    late _Downloads downloads;
    late AppUpdateCubit cubit;

    setUp(() async {
      downloads = _Downloads();
      cubit = AppUpdateCubit(
        repository: FakeAppUpdateRepository(
          latest: testRelease(3),
          installed: const AppVersion(1, 2, 0),
        ),
        downloads: downloads,
      );
      await cubit.check();
    });
    tearDown(() => cubit.close());

    Future<void> prepare() async {
      final pending = cubit.download();
      downloads.result.complete('/private/app_updates/update.apk');
      await pending;
    }

    test(
      'progress reaches verifying before the verified APK becomes ready',
      () async {
        final pending = cubit.download();
        downloads.progress!(24, 59);
        expect(cubit.state.phase, AppUpdatePhase.downloading);
        expect(cubit.state.progress, closeTo(24 / 59, .001));
        downloads.progress!(59, 59);
        expect(cubit.state.phase, AppUpdatePhase.verifying);
        await cubit.download();
        expect(downloads.starts, 1);
        downloads.result.complete('/private/app_updates/update.apk');
        await pending;
        expect(cubit.state.phase, AppUpdatePhase.ready);
      },
    );

    test(
      'cancellation ignores late progress and completion, then allows retry',
      () async {
        final pending = cubit.download();
        final staleProgress = downloads.progress!;
        final staleResult = downloads.result;
        await cubit.cancelDownload();
        staleProgress(59, 59);
        staleResult.complete('/old.apk');
        await pending;
        expect(cubit.state.phase, AppUpdatePhase.available);
        downloads.result = Completer<String>();
        await prepare();
        expect(downloads.starts, 2);
        expect(cubit.state.phase, AppUpdatePhase.ready);
      },
    );

    test(
      'verification failure offers retry and never installs the file',
      () async {
        final pending = cubit.download();
        downloads.result.completeError(
          const AppUpdateFailure(AppUpdateFailureKind.invalidFile),
        );
        await pending;
        expect(cubit.state.phase, AppUpdatePhase.failed);
        expect(cubit.state.failure, AppUpdateFailureKind.invalidFile);
        await cubit.install();
        expect(downloads.installed, isEmpty);
      },
    );

    test('a validated APK is restored after relaunch', () async {
      downloads.restored = '/private/app_updates/update.apk';
      await cubit.check();
      expect(cubit.state.phase, AppUpdatePhase.ready);
      await cubit.dismiss();
      expect(cubit.state.release, isNotNull);
    });

    test(
      'permission return installs only after permission is granted',
      () async {
        await prepare();
        downloads.permission = false;
        await cubit.install();
        expect(downloads.settingsOpened, 1);
        expect(downloads.installed, isEmpty);
        downloads.permission = true;
        await cubit.resumeInstallation();
        expect(downloads.installed, ['/private/app_updates/update.apk']);
        expect(cubit.state.phase, AppUpdatePhase.ready);
        await cubit.resumeInstallation();
        expect(downloads.installed, hasLength(1));
      },
    );

    test(
      'permission denial keeps APK ready and does not reopen settings',
      () async {
        await prepare();
        downloads.permission = false;
        await cubit.install();
        await cubit.resumeInstallation();
        expect(cubit.state.phase, AppUpdatePhase.ready);
        expect(cubit.state.failure, AppUpdateFailureKind.permission);
        expect(downloads.settingsOpened, 1);
        expect(downloads.installed, isEmpty);
      },
    );

    test(
      'installer failure keeps the prepared file available for retry',
      () async {
        await prepare();
        downloads.installFailure = AppUpdateFailureKind.install;
        await cubit.install();
        expect(cubit.state.failure, AppUpdateFailureKind.install);
        expect(cubit.state.phase, AppUpdatePhase.ready);
        downloads.installFailure = null;
        await cubit.install();
        expect(downloads.installed, hasLength(1));
        expect(cubit.state.failure, isNull);
      },
    );

    test('a late restore cannot replace an active download', () async {
      downloads.restoreResult = Completer<String?>();
      final check = cubit.check();
      await Future<void>.delayed(Duration.zero);
      final pending = cubit.download();
      downloads.restoreResult!.complete('/old.apk');
      await check;
      expect(cubit.state.phase, AppUpdatePhase.downloading);
      downloads.result.complete('/new.apk');
      await pending;
      await cubit.install();
      expect(downloads.installed, ['/new.apk']);
    });

    test(
      'an invalid APK rejected by Android returns to download retry',
      () async {
        await prepare();
        downloads.installFailure = AppUpdateFailureKind.invalidFile;
        await cubit.install();
        expect(cubit.state.phase, AppUpdatePhase.failed);
        expect(cubit.state.failure, AppUpdateFailureKind.invalidFile);
        expect(downloads.installed, isEmpty);
        downloads.installFailure = null;
        await cubit.install();
        expect(downloads.installed, isEmpty);
      },
    );

    test('closing ignores a download that finishes during teardown', () async {
      final pending = cubit.download();
      await cubit.close();
      downloads.progress!(59, 59);
      downloads.result.complete('/late.apk');
      await pending;
      expect(cubit.isClosed, isTrue);
    });
  });
}

class _Downloads implements AppUpdateDownloadRepository {
  Completer<String> result = Completer<String>();
  Completer<String?>? restoreResult;
  String? restored;
  void Function(int, int)? progress;
  int starts = 0;
  int settingsOpened = 0;
  bool permission = true;
  AppUpdateFailureKind? installFailure;
  final installed = <String>[];

  @override
  Future<String?> restore(AppRelease release) async =>
      restoreResult == null ? restored : restoreResult!.future;

  @override
  Future<String> download(
    AppRelease release, {
    required void Function(int, int) onProgress,
  }) {
    starts++;
    progress = onProgress;
    return result.future;
  }

  @override
  Future<void> cancel() async {}
  @override
  Future<bool> canInstall() async => permission;
  @override
  Future<void> openInstallPermissionSettings() async => settingsOpened++;
  @override
  Future<void> install(String path) async {
    if (installFailure case final failure?) {
      throw AppUpdateFailure(failure);
    }
    installed.add(path);
  }
}
