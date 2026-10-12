import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_version.dart';
import 'package:iris/features/app_update/domain/repositories/app_update_repository.dart';

class FakeAppUpdateRepository implements AppUpdateRepository {
  FakeAppUpdateRepository({this.latest, this.installed, this.dismissed});

  AppRelease? latest;
  AppVersion? installed;
  AppVersion? dismissed;
  bool failing = false;

  @override
  Future<AppRelease?> latestRelease() async {
    if (failing) throw Exception('offline');
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
