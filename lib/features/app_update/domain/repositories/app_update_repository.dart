import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_version.dart';

abstract interface class AppUpdateRepository {
  /// The newest published release with a build for this platform; null
  /// when there is none, or the platform takes no updates this way (iOS).
  Future<AppRelease?> latestRelease();

  /// The version running now.
  Future<AppVersion?> installedVersion();

  /// The release the user put off, so it is not offered again.
  AppVersion? get dismissedVersion;

  Future<void> dismiss(AppVersion version);
}
