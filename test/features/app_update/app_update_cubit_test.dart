import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/app_update/data/github_app_update_repository.dart';
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
    expect(cubit.state.installedVersion, const AppVersion(1, 2, 0));
    expect(cubit.state.checkStatus, AppUpdateCheckStatus.idle);
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
    expect(cubit.state.dismissedRelease, testRelease(3));
    expect(cubit.state.hasDismissedUpdate, isTrue);
    expect(repository.dismissed, const AppVersion(1, 3, 0));

    await cubit.check();
    expect(cubit.state.release, isNull);
    expect(cubit.state.dismissedRelease, testRelease(3));
    expect(cubit.state.hasDismissedUpdate, isTrue);

    repository.latest = testRelease(4);
    await cubit.check();
    expect(cubit.state.release, testRelease(4));
    expect(cubit.state.dismissedRelease, isNull);
    expect(cubit.state.hasDismissedUpdate, isFalse);
  });

  test(
    'dismissed release clears once installed and can start downloading directly',
    () async {
      final release = testRelease(3);
      final repository = FakeAppUpdateRepository(
        latest: release,
        installed: const AppVersion(1, 2, 0),
      );
      final downloads = _Downloads();
      final cubit = AppUpdateCubit(
        repository: repository,
        downloads: downloads,
      );
      addTearDown(cubit.close);

      await cubit.check();
      await cubit.dismiss();
      expect(cubit.state.release, isNull);
      expect(cubit.state.dismissedRelease, release);

      final pending = cubit.download();
      expect(cubit.state.release, release);
      expect(cubit.state.dismissedRelease, isNull);
      expect(cubit.state.phase, AppUpdatePhase.downloading);
      downloads.result.complete('/tmp/update.apk');
      await pending;
      expect(cubit.state.phase, AppUpdatePhase.ready);

      // A relaunched cubit on the updated version does not flag a dismissed update.
      final updated = AppUpdateCubit(
        repository: FakeAppUpdateRepository(
          latest: release,
          installed: release.version,
          dismissed: release.version,
        ),
      );
      addTearDown(updated.close);
      await updated.check();
      expect(updated.state.release, isNull);
      expect(updated.state.dismissedRelease, isNull);
      expect(updated.state.hasDismissedUpdate, isFalse);
    },
  );

  test('a failed check offers nothing', () async {
    final cubit = await checked(
      FakeAppUpdateRepository(
        latest: testRelease(3),
        installed: const AppVersion(1, 2, 0),
      )..failing = true,
    );

    expect(cubit.state.release, isNull);
    expect(cubit.state.checkStatus, AppUpdateCheckStatus.idle);
  });

  group('installed version', () {
    test('can be loaded on a platform without update checks', () async {
      var reads = 0;
      final cubit = AppUpdateCubit(
        repository: NoAppUpdateRepository(
          installed: () async {
            reads++;
            return '1.2.3+4';
          },
        ),
      );
      addTearDown(cubit.close);

      expect(cubit.supportsCheck, isFalse);
      await cubit.checkManually();
      expect(reads, 0);
      expect(cubit.state, const AppUpdateState());
      await cubit.loadInstalledVersion();
      await cubit.loadInstalledVersion();

      expect(cubit.state.installedVersion, const AppVersion(1, 2, 3));
      expect(cubit.state.checkStatus, AppUpdateCheckStatus.idle);
      expect(reads, 1);
    });

    test('a version read failure is silent and can be retried', () async {
      var failing = true;
      final cubit = AppUpdateCubit(
        repository: NoAppUpdateRepository(
          installed: () async {
            if (failing) throw StateError('package information unavailable');
            return '1.2.3';
          },
        ),
      );
      addTearDown(cubit.close);

      await cubit.loadInstalledVersion();
      expect(cubit.state, const AppUpdateState());

      failing = false;
      await cubit.loadInstalledVersion();
      expect(cubit.state.installedVersion, const AppVersion(1, 2, 3));
    });

    test('ignores installed version answers after closing', () async {
      final answer = Completer<String?>();
      final cubit = AppUpdateCubit(
        repository: NoAppUpdateRepository(installed: () => answer.future),
      );

      final loading = cubit.loadInstalledVersion();
      await cubit.close();
      answer.complete('1.2.3');
      await loading;
      expect(cubit.state, const AppUpdateState());
    });
  });

  group('manual checks', () {
    const installed = AppVersion(1, 2, 0);

    test('rediscovers an update the user put off', () async {
      final release = testRelease(3);
      final repository = FakeAppUpdateRepository(
        latest: release,
        installed: installed,
      );
      final cubit = await checked(repository);

      await cubit.dismiss();
      await cubit.check();
      expect(cubit.state.release, isNull);
      expect(cubit.supportsCheck, isTrue);

      await cubit.checkManually();

      expect(
        cubit.state,
        AppUpdateState(
          release: release,
          installedVersion: installed,
          checkStatus: AppUpdateCheckStatus.available,
        ),
      );
      expect(repository.dismissedVersion, release.version);
    });

    test(
      'keeps the ready update visible during the check and restores its file',
      () async {
        final release = testRelease(3);
        final repository = FakeAppUpdateRepository(
          latest: release,
          installed: installed,
        );
        final downloads = _Downloads()..restored = '/ready.apk';
        final cubit = AppUpdateCubit(
          repository: repository,
          downloads: downloads,
        );
        addTearDown(cubit.close);
        await cubit.check();
        final answer = Completer<AppRelease?>();
        repository.pendingLatest = answer;

        final checking = cubit.checkManually();
        expect(cubit.state.checkStatus, AppUpdateCheckStatus.checking);
        expect(cubit.state.release, release);
        expect(cubit.state.phase, AppUpdatePhase.ready);
        expect(cubit.state.installedVersion, installed);
        await cubit.checkManually();
        await cubit.check();
        expect(repository.latestReads, 2);

        answer.complete(release);
        await checking;
        expect(cubit.state.checkStatus, AppUpdateCheckStatus.available);
        expect(cubit.state.phase, AppUpdatePhase.ready);
        await cubit.install();
        expect(downloads.installed, ['/ready.apk']);
        expect(cubit.state.installedVersion, installed);
      },
    );

    test(
      'reports up to date and clears the offer when the build is absent',
      () async {
        final release = testRelease(3);
        final repository = FakeAppUpdateRepository(
          latest: release,
          installed: installed,
        );
        final cubit = await checked(repository);

        repository.installed = release.version;
        await cubit.checkManually();
        expect(cubit.state.checkStatus, AppUpdateCheckStatus.upToDate);
        expect(cubit.state.installedVersion, release.version);
        expect(cubit.state.release, release);

        repository.latest = null;
        await cubit.checkManually();
        expect(
          cubit.state,
          AppUpdateState(
            installedVersion: release.version,
            checkStatus: AppUpdateCheckStatus.upToDate,
          ),
        );
      },
    );

    test(
      'a failed lookup keeps the current offer and installed version',
      () async {
        final release = testRelease(3);
        final repository = FakeAppUpdateRepository(
          latest: release,
          installed: installed,
        );
        final cubit = await checked(repository);
        final previous = cubit.state;
        repository.failing = true;

        await cubit.checkManually();

        expect(
          cubit.state,
          previous.copyWith(checkStatus: AppUpdateCheckStatus.failed),
        );
      },
    );

    test('a restore failure preserves the earlier prepared download', () async {
      final release = testRelease(3);
      final repository = FakeAppUpdateRepository(
        latest: release,
        installed: installed,
      );
      final downloads = _Downloads()..restored = '/ready.apk';
      final cubit = AppUpdateCubit(
        repository: repository,
        downloads: downloads,
      );
      addTearDown(cubit.close);
      await cubit.check();
      final previous = cubit.state;
      repository.latest = testRelease(4);
      repository.installed = const AppVersion(1, 2, 1);
      final restore = Completer<String?>();
      downloads.restoreResult = restore;

      final checking = cubit.checkManually();
      await Future<void>.delayed(Duration.zero);
      restore.completeError(StateError('storage unavailable'));
      await checking;

      expect(
        cubit.state,
        previous.copyWith(checkStatus: AppUpdateCheckStatus.failed),
      );
      await cubit.install();
      expect(downloads.installed, ['/ready.apk']);
    });

    test(
      'a download supersedes a manual check and blocks further checks',
      () async {
        final release = testRelease(3);
        final repository = FakeAppUpdateRepository(
          latest: release,
          installed: installed,
        );
        final downloads = _Downloads();
        final cubit = AppUpdateCubit(
          repository: repository,
          downloads: downloads,
        );
        addTearDown(cubit.close);
        await cubit.check();
        final answer = Completer<AppRelease?>();
        repository.pendingLatest = answer;

        final checking = cubit.checkManually();
        final downloading = cubit.download();
        await cubit.checkManually();
        expect(repository.latestReads, 2);
        answer.complete(testRelease(4));
        await checking;

        expect(cubit.state.release, release);
        expect(cubit.state.phase, AppUpdatePhase.downloading);
        expect(cubit.state.checkStatus, AppUpdateCheckStatus.idle);
        expect(cubit.state.installedVersion, installed);
        downloads.result.complete('/downloaded.apk');
        await downloading;
      },
    );
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
        final cancelGate = downloads.cancelGate = Completer<void>();
        final cancelling = cubit.cancelDownload();
        expect(cubit.state.cancelling, isTrue);
        await cubit.cancelDownload();
        await cubit.download();
        expect(downloads.cancels, 1);
        expect(downloads.starts, 1);
        staleProgress(59, 59);
        staleResult.complete('/old.apk');
        await pending;
        expect(cubit.state.phase, AppUpdatePhase.downloading);
        cancelGate.complete();
        await cancelling;
        expect(cubit.state.phase, AppUpdatePhase.available);
        expect(cubit.state.cancelling, isFalse);
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
      'a pending or denied permission check keeps the APK ready without opening the installer',
      () async {
        await prepare();
        downloads.permission = false;
        final permission = downloads.permissionResult = Completer<bool>();
        final states = <AppUpdateState>[];
        final subscription = cubit.stream.listen(states.add);
        addTearDown(subscription.cancel);
        final installing = cubit.install();
        expect(cubit.state.phase, AppUpdatePhase.ready);
        await cubit.install();
        expect(downloads.permissionChecks, 1);
        permission.complete(false);
        await installing;
        expect(cubit.state.failure, AppUpdateFailureKind.permission);
        await cubit.resumeInstallation();
        expect(states.map((state) => state.phase), [AppUpdatePhase.ready]);
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
  Completer<void>? cancelGate;
  Completer<bool>? permissionResult;
  String? restored;
  void Function(int, int)? progress;
  int starts = 0;
  int cancels = 0;
  int permissionChecks = 0;
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
  Future<void> cancel() async {
    cancels++;
    await cancelGate?.future;
  }

  @override
  Future<bool> canInstall() async {
    permissionChecks++;
    if (permissionResult case final pending?) return pending.future;
    return permission;
  }

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
