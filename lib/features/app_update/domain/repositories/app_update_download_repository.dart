import 'package:iris/features/app_update/domain/entities/app_release.dart';

abstract interface class AppUpdateDownloadRepository {
  Future<String?> restore(AppRelease release);

  Future<String> download(
    AppRelease release, {
    required void Function(int received, int total) onProgress,
  });

  Future<void> cancel();
  Future<bool> canInstall();
  Future<void> openInstallPermissionSettings();
  Future<void> install(String path);
}
