import 'package:iris/features/app_update/domain/entities/app_version.dart';

/// A published release with a build for this platform.
class AppRelease {
  const AppRelease({required this.version, required this.downloadUrl});

  final AppVersion version;

  /// This platform's build: an APK on Android, an archive on Windows.
  final Uri downloadUrl;

  @override
  bool operator ==(Object other) =>
      other is AppRelease &&
      other.version == version &&
      other.downloadUrl == downloadUrl;

  @override
  int get hashCode => Object.hash(version, downloadUrl);
}
