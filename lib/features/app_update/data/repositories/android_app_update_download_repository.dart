import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:iris/features/app_update/data/repositories/app_update_file_downloader.dart';
import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_update_failure.dart';
import 'package:iris/features/app_update/domain/repositories/app_update_download_repository.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/platform/download_foreground_service_adapter.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';

class AndroidAppUpdateDownloadRepository
    implements AppUpdateDownloadRepository {
  AndroidAppUpdateDownloadRepository({
    required Dio dio,
    required DownloadForegroundServiceAdapter foregroundService,
    Future<Directory> Function()? supportDirectory,
    MethodChannel installer = const MethodChannel('iris/app_update'),
    TargetPlatform? platform,
  }) : _foregroundService = foregroundService,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _installer = installer,
       _platform = platform ?? defaultTargetPlatform,
       _files = AppUpdateFileDownloader(
         dio: dio,
         supportDirectory: supportDirectory ?? getApplicationSupportDirectory,
         extension: '.apk',
         onDownloadStarted: (release) =>
             foregroundService.start(text: '${release.version}'),
         onDownloadFinished: foregroundService.stop,
       );

  final DownloadForegroundServiceAdapter _foregroundService;
  final Future<Directory> Function() _supportDirectory;
  final MethodChannel _installer;
  final TargetPlatform _platform;
  final AppUpdateFileDownloader _files;

  @override
  Future<String?> restore(AppRelease release) => _files.restore(release);

  @override
  Future<String> download(
    AppRelease release, {
    required void Function(int received, int total) onProgress,
  }) => _files.download(
    release,
    onProgress: onProgress,
    platformAllowed: _platform == TargetPlatform.android,
    onTransferProgress: (received, total) {
      final localizations = _systemLocalizations();
      return _foregroundService.update(
        text:
            '${release.version} · ${formatByteSize(localizations, received, compact: true)} / ${formatByteSize(localizations, total, compact: true)}',
      );
    },
  );

  @override
  Future<void> cancel() => _files.cancel();

  @override
  Future<bool> canInstall() async {
    if (_platform != TargetPlatform.android) return false;
    try {
      return await _installer.invokeMethod<bool>('canInstall') ?? false;
    } on Object {
      throw const AppUpdateFailure(AppUpdateFailureKind.permission);
    }
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    if (_platform != TargetPlatform.android) {
      throw const AppUpdateFailure(AppUpdateFailureKind.permission);
    }
    try {
      await _installer.invokeMethod<void>('openInstallPermissionSettings');
    } on Object {
      throw const AppUpdateFailure(AppUpdateFailureKind.permission);
    }
  }

  @override
  Future<void> install(String filePath) async {
    if (_platform != TargetPlatform.android) {
      throw const AppUpdateFailure(AppUpdateFailureKind.install);
    }
    try {
      final directory = Directory(
        path.join((await _supportDirectory()).path, 'app_updates'),
      );
      final root = path.canonicalize(directory.path);
      final candidate = path.canonicalize(path.absolute(filePath));
      final file = File(candidate);
      if (!path.isWithin(root, candidate) ||
          !candidate.toLowerCase().endsWith('.apk') ||
          !await file.exists()) {
        throw const AppUpdateFailure(AppUpdateFailureKind.invalidFile);
      }
      await _installer.invokeMethod<void>('install', {'path': candidate});
    } on AppUpdateFailure {
      rethrow;
    } on PlatformException catch (error) {
      throw AppUpdateFailure(switch (error.code) {
        'invalid_apk' => AppUpdateFailureKind.invalidFile,
        'install_permission_required' => AppUpdateFailureKind.permission,
        _ => AppUpdateFailureKind.install,
      });
    } on Object {
      throw const AppUpdateFailure(AppUpdateFailureKind.install);
    }
  }
}

AppLocalizations _systemLocalizations() => lookupAppLocalizations(
  basicLocaleListResolution(
    PlatformDispatcher.instance.locales,
    AppLocalizations.supportedLocales,
  ),
);
