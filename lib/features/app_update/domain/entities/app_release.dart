import 'package:iris/features/app_update/domain/entities/app_version.dart';

/// A published release with a build for this platform.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.downloadUrl,
    this.notes = '',
    this.sizeBytes = 0,
    this.sha256,
    this.assetName = '',
  });

  final AppVersion version;

  /// This platform's build: an APK on Android, an archive on Windows.
  final Uri downloadUrl;

  final String notes;
  final int sizeBytes;

  /// A lowercase SHA-256 hex digest, when supplied by GitHub.
  final String? sha256;

  final String assetName;

  @override
  bool operator ==(Object other) =>
      other is AppRelease &&
      other.version == version &&
      other.downloadUrl == downloadUrl &&
      other.notes == notes &&
      other.sizeBytes == sizeBytes &&
      other.sha256 == sha256 &&
      other.assetName == assetName;

  @override
  int get hashCode =>
      Object.hash(version, downloadUrl, notes, sizeBytes, sha256, assetName);
}
