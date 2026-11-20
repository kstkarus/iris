import 'dart:async';

import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_version.dart';
import 'package:iris/features/app_update/domain/repositories/app_update_repository.dart';

class FakeAppUpdateRepository implements AppUpdateRepository {
  FakeAppUpdateRepository({
    this.latest,
    this.installed,
    this.dismissed,
    this.supportsCheck = true,
  });

  AppRelease? latest;
  AppVersion? installed;
  AppVersion? dismissed;
  bool failing = false;
  Completer<AppRelease?>? pendingLatest;
  int latestReads = 0;

  @override
  final bool supportsCheck;

  @override
  Future<AppRelease?> latestRelease() async {
    latestReads++;
    if (failing) throw Exception('offline');
    if (pendingLatest case final pending?) return pending.future;
    return latest;
  }

  @override
  Future<AppVersion?> installedVersion() async => installed;

  @override
  AppVersion? get dismissedVersion => dismissed;

  @override
  Future<void> dismiss(AppVersion version) async => dismissed = version;
}

AppRelease testRelease(int minor) => AppRelease(
  version: AppVersion(1, minor, 0),
  downloadUrl: Uri.parse('https://example.org/iris-1.$minor.0-android.apk'),
);
